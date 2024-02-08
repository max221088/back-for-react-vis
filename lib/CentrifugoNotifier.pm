package CentrifugoNotifier;

use strict;
use warnings;

use JSON;
use HTTP::Request;
use LWP::UserAgent;
use URI;

sub new{
    my ($centrifugo_notifier, $centrifugo_url, $centrifugo_channel, $api_key) = @_;

    my $self = {
        'centrifugo_url' => $centrifugo_url,
        'centrifugo_channel' => $centrifugo_channel,
        'api_key' => $api_key,
    };

    bless $self, $centrifugo_notifier;

    return $self;
}

sub send_message {
    my ($self, $data) = @_;

    my $json = encode_json({ channel => $self->{centrifugo_channel}, data => $data });

    my $uri = URI->new("publish")->abs($self->{centrifugo_url});
    my $req = HTTP::Request->new('POST', $uri);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-API-Key'    => $self->{api_key});
    $req->content($json);

    my $lwp = LWP::UserAgent->new;
    $lwp->request($req);
}

1;
