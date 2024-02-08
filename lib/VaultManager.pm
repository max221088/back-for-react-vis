package VaultManager;

use strict;
use warnings;
use JSON;
use Data::Dumper;
use List::Util 'first';
use Data::UUID;

use SimpleFile;
use MarkdownHelper;
use BackupHelper;

sub new {
    my ($vault_manager, $vaults_folder, $metadata_file_name, $backup_path) = @_;

    my $backup_helper = BackupHelper->new($backup_path);
    my $self = {
        vaults_folder      => $vaults_folder,
        metadata_file_name => $metadata_file_name,
        backup_helper      => $backup_helper
    };

    my @folders = SimpleFile->dir_folders($vaults_folder);
    for my $folder (@folders) {
        my $metadata_path = SimpleFile->resolve_path($vaults_folder, $folder, $metadata_file_name);

        if (-e $metadata_path) {
            my $metadata = SimpleFile->read_json($metadata_path);

            if ($metadata->{vault}{id}) {
                $self->{vaults}{$metadata->{vault}{id}} = {
                    metadata      => $metadata,
                    metadata_path => $metadata_path,
                    path          => SimpleFile->resolve_path($vaults_folder, $folder)
                };
            }
        }
    }

    bless $self, $vault_manager;

    return $self;
}

sub get_all_metadata {
    my $self = shift;
    my @vaults = values %{$self->{vaults}};

    return map {$_->{metadata}} @vaults;
}

sub get_by_id {
    my ($self, $id) = @_;
    return $self->{vaults}{$id}{metadata};
}

sub apply_changes {
    my ($self, $new_metadata) = @_;
    my $vault_id = $new_metadata->{vault}{id};
    my $vault_metadata = $self->{vaults}{$vault_id}{metadata};
    my $vault_folder = $self->{vaults}{$vault_id}{path};

    unless (defined $vault_metadata) {
        return;
    }

    my $ug = Data::UUID->new;

    my ($added_nodes, $removed_nodes) = MarkdownHelper->nodes_diff($vault_metadata->{nodes}, $new_metadata->{nodes});
    my ($added_edges, $removed_edges) = MarkdownHelper->edges_diff($vault_metadata->{edges}, $new_metadata->{edges});

    if ($ENV{TARGET} eq "development") {
        print "\nADDED NODES:\n", Dumper $added_nodes;
        print "\nADDED LINKS:\n", Dumper $added_edges;
        print "\nREMOVED NODES:\n", Dumper $removed_nodes;
        print "\nREMOVED LINKS:\n", Dumper $removed_edges;
    }

    for my $node (@$added_nodes) {
        if ($node->{type} eq "FILE") {
            my $parent = $self->{vaults}{$node->{parent}};
            my $absolute_path = SimpleFile->resolve_path($vault_folder, $node->{relativePath});

            SimpleFile->copy_file(
                SimpleFile->resolve_path($parent->{path}, $node->{relativePath}),
                $absolute_path
            );

            $node->{parent} = $vault_id;
            $node->{absolutePath} = $absolute_path;
        }

        my $new_id = $ug->create_str();
        for my $edge (@$added_edges) {
            if ($edge->{from} eq $node->{id}) {
                $edge->{from} = $new_id;
            }
            elsif ($edge->{to} eq $node->{id}) {
                $edge->{to} = $new_id;
            }
        }

        $node->{id} = $new_id;
    }

    if ($ENV{TARGET} eq "development") {
        print "\nADDED NODES after normalization:\n", Dumper $added_nodes;
        print "\nADDED LINKS after normalization:\n", Dumper $added_edges;
        print "\nREMOVED NODES after normalization:\n", Dumper $removed_nodes;
        print "\nREMOVED LINKS after normalization:\n", Dumper $removed_edges;
    }

    for my $node (@$removed_nodes) {
        if ($node->{type} eq "FILE") {
            SimpleFile->delete(SimpleFile->resolve_path($vault_folder, $node->{relativePath}));
        }
    }

    for my $edge (@$added_edges) {
        my ($from_node, $to_node) = MarkdownHelper->validate_edge($new_metadata->{nodes}, $edge);
        MarkdownHelper->add_tag(
            SimpleFile->resolve_path($vault_folder, $from_node->{relativePath}),
            $to_node->{name}
        ) if $from_node && $to_node;
    }

    for my $edge (@$removed_edges) {
        my ($from_node, $to_node) = MarkdownHelper->validate_edge($vault_metadata->{nodes}, $edge);
        MarkdownHelper->remove_tag(
            SimpleFile->resolve_path($vault_folder, $from_node->{relativePath}),
            $to_node->{name}
        ) if $from_node && $to_node;
    }

    $self->{vaults}{$vault_id}{metadata} = $new_metadata;
}

sub rewrite_metadata {
    my ($self, $id) = @_;
    my $vault = $self->{vaults}{$id};

    SimpleFile->write_file($vault->{metadata_path}, encode_json($vault->{metadata})) if defined $vault;
}

sub create_backup {
    my ($self, $id) = @_;
    my $vault = $self->{vaults}{$id};

    $self->{backup_helper}->create_backup($id, encode_json($vault->{metadata})) if defined $vault;
}

sub reset_backup {
    my ($self, $id) = @_;
    my $vault = $self->{vaults}{$id};

    my $last_backup = $self->{backup_helper}->get_last_backup($id);

    if (defined $last_backup) {
        $self->apply_changes($last_backup);

        $self->rewrite_metadata($id);

        $self->{backup_helper}->delete_last_backup($id);

        return $vault->{metadata};
    }
}

1;
