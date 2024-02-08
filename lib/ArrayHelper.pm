package ArrayHelper;

use strict;
use warnings;

sub array_diff {
    my ($self, $original, $new, $id_resolver) = @_;

    my %count;

    sub count_elements {
        my ($array, $source, $counter, $id_resolver) = @_;

        for my $element (@{$array}) {
            my $id = defined $id_resolver ? $id_resolver->($element) : $element->{id};

            $counter->{$id}{count}++;
            $counter->{$id}{source} = $source;
            $counter->{$id}{element} = $element;
        }
    }

    count_elements($original, "original", \%count, $id_resolver);
    count_elements($new, "new", \%count, $id_resolver);

    my @added;
    my @removed;

    for my $id (keys %count) {
        if ($count{$id}{count} == 1) {
            push
                @{$count{$id}{source} eq "new" ? \@added : \@removed},
                $count{$id}{element};
        }
    }

    return (\@added, \@removed);
}

1;
