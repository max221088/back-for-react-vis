package MarkdownHelper;

use strict;
use warnings;

use List::Util 'first';
use Data::Dumper;

use SimpleFile;
use ArrayHelper;

sub edges_diff {
    my ($self, $original_edges, $new_edges) = @_;

    return ArrayHelper->array_diff(
        $original_edges,
        $new_edges,
        sub {
            my $edge = shift;
            return "$edge->{from}-$edge->{to}";
        }
    );
}

sub nodes_diff {
    my ($self, $original_nodes, $new_nodes) = @_;

    return ArrayHelper->array_diff(
        $original_nodes,
        $new_nodes
    );
}

sub add_tag {
    my ($self, $path, $tag) = @_;

    if (!-e $path) {
        return;
    }

    my $file = SimpleFile->read_file($path);
    if ($file !~ /\s$tag\s/) {
        if ($file =~ /\s\\$tag\s/) {
            $file =~ s/(\s)\\$tag(\s)/$1$tag$2/;
        }
        elsif ($file =~ /__TAGS__\s/) {
            $file =~ s/__TAGS__/__TAGS__ $tag/;
        }
        else {
            $file .= "\n\n__TAGS__ $tag\n";
        }

        SimpleFile->write_file($path, $file);

        if ($ENV{TARGET} eq "development") {
            print "\n$tag tag was added to $path\n";
        }
    }
}

sub remove_tag {
    my ($self, $path, $tag) = @_;

    if (!-e $path) {
        return;
    }

    my $file = SimpleFile->read_file($path);
    $file =~ s/((\s)($tag))+(\s)/$2\\$tag$4/g;

    SimpleFile->write_file($path, $file);

    if ($ENV{TARGET} eq "development") {
        print "\n$tag tag was removed from $path\n";
    }
}

sub validate_edge {
    my ($self, $nodes, $edge) = @_;

    my $from_node = first {$_->{id} eq $edge->{from}} @{$nodes};
    my $to_node = first {$_->{id} eq $edge->{to}} @{$nodes};

    if ($from_node && $to_node && $from_node->{type} eq "FILE" && $to_node->{type} eq "TAG") {
        return ($from_node, $to_node);
    }
}

1;
