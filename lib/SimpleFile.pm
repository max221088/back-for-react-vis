package SimpleFile;

use strict;
use warnings;

use File::Spec;
use File::Copy;
use JSON;

sub read_file {
    my ($self, $path, $interceptor) = @_;
    my $res = "";

    open FH, '<', $path or die "Can't open $path: $!";

    while (<FH>) {
        $res .= $_;
        $interceptor->($_) if defined $interceptor;
    }
    close FH;

    return $res;
}

sub write_file {
    my ($self, $path, $data) = @_;

    open(FH, '>', $path) or die $!;
    print FH $data;
    close(FH);
}

sub dir_folders {
    my ($self, $path) = @_;

    opendir(my $dh, $path) or die "Can't open directory '$path': $!";
    my @folders = grep { -d File::Spec->catdir($path, $_) && !/^\.{1,2}$/ } readdir($dh);
    closedir($dh);

    return @folders;
}

sub resolve_path {
    my $self = shift;
    my @paths = @_;

    for my $index (0 .. $#paths) {
        if ($index == 0) {
            next;
        }

        my $path = $paths[$index];
        $path =~ s/^\.[\\\/]//;
        $paths[$index] = $path;
    }

    return File::Spec->rel2abs(File::Spec->catfile(@paths));
}

sub read_json {
    my ($self, $path) = @_;
    my $file = $self->read_file($path);
    return decode_json($file);
}

sub copy_file {
    my ($self, $from, $to) = @_;
    copy($from, $to) or die "Copy failed: $!";
}

sub move_file {
    my ($self, $from, $to) = @_;
    move($from, $to) or die "Move failed: $!";
}

sub delete {
    my ($self, $path) = @_;
    unlink($path) or die "Delete failed: $!";
}

1;
