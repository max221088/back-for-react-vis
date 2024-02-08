package EnvLoader;

use strict;
use warnings;

use SimpleFile;

sub load {
    my ($self, $path) = @_;

    SimpleFile->read_file($path, sub {
        my ($line) = @_;
        chomp $line;

        return if $line =~ /^\s*$/ || $line =~ /^\s*#/;

        if ($line =~ /([^=]+)=(.*)/) {
            my $key = $1;
            my $value = $2;
            $value =~ s/^"(.*?)"\s*$/$1/;
            $ENV{$key} = $value;
        }
    });
}

sub load_centrifugo_config {
    my ($self, $path) = @_;
    my $config = SimpleFile->read_json($path);

    $ENV{api_key} = $config->{api_key};
    $ENV{token_hmac_secret_key} = $config->{token_hmac_secret_key};
}

1;
