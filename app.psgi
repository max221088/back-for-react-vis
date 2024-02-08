# !/usr/bin/env perl
use strict;
use warnings;

use Plack;
use Plack::Request;
use Plack::Builder;
use JSON;
use JSON::WebToken;
use Data::Dumper;

use lib::EnvLoader;
use lib::SimpleFile;
use lib::BackupHelper;
use lib::CentrifugoNotifier;
use lib::MarkdownHelper;
use lib::VaultManager;

EnvLoader->load('.env');
EnvLoader->load_centrifugo_config($ENV{PATH_TO_CENTRIFUGO_CONFIG});

my $vault_manager = VaultManager->new(
    $ENV{PATH_TO_TRACKING_DIRs},
    $ENV{METADATA_FILE_NAME},
    $ENV{BACKUP_FOLDER}
);
my $centrifugo_notifier = CentrifugoNotifier->new(
    $ENV{CENTRIFUGO_URL},
    $ENV{CENTRIFUGO_CHANNEL},
    $ENV{api_key}
);


my $user_index = 0;

`mkdir -p $ENV{BACKUP_FOLDER}`;

sub requestWrapper {
    my $cb = shift;

    return sub {
        my $env = shift;

        my $req = Plack::Request->new($env);
        my $res = $req->new_response(200);
        $res->header('Content-Type' => 'application/json');

        $cb->($req, $res);

        return $res->finalize();
    }
}

my $get_metadata = requestWrapper(sub {
    my ($req, $res) = @_;
    my @metadata = $vault_manager->get_all_metadata();
    $res->body(encode_json(\@metadata));
});

my $get_token = requestWrapper(sub {
    my ($req, $res) = @_;

    my $token = encode_jwt(
        {
            sub => $user_index++,
            exp => time() + 60 * 60,
            iat => time()
        },
        $ENV{token_hmac_secret_key},
        'HS256',
        { typ => 'JWT' }
    );

    $res->body(encode_json({ token => $token }));
});

my $change_metadata = requestWrapper(sub {
    my ($req, $res) = @_;

    my $metadata = decode_json($req->content());

    $vault_manager->create_backup($metadata->{vault}{id});
    $vault_manager->apply_changes($metadata);
    $vault_manager->rewrite_metadata($metadata->{vault}{id});

    $centrifugo_notifier->send_message({newMetadata => $vault_manager->get_all_metadata()});

    $res->body(encode_json({ status => "OK" }));
});


my $reset_metadata = requestWrapper(sub {
    my ($req, $res) = @_;

    my $args = decode_json($req->content());
    my $vault_id = $args->{vaultId};

    my $new_metadata = $vault_manager->reset_backup($vault_id);

    if (defined $new_metadata) {
        $centrifugo_notifier->send_message({newMetadata => $vault_manager->get_all_metadata()});
    }

    $res->body(encode_json({ status => "OK" }));
});

my $root_app = builder {
    enable sub {
        my $app = shift;

        return sub {
            my $env = shift;

            if ($env->{REQUEST_METHOD} eq "OPTIONS") {
                my $req = Plack::Request->new($env);
                my $res = $req->new_response(200);
                $res->header('Access-Control-Allow-Origin' => '*');
                $res->header('Access-Control-Allow-Methods' => '*');
                $res->header('Access-Control-Allow-Headers' => '*');
                $res->header('Access-Control-Max-Age' => 3600);

                return $res->finalize();
            }

            return $app->($env);
        }
    };
    enable 'CrossOrigin', origins => '*', methods => ['GET', 'POST'];

    mount "/" => builder {$get_metadata};
    mount "/change" => builder {$change_metadata};
    mount "/get-token" => builder {$get_token};
    mount "/reset" => builder {$reset_metadata;};
};
