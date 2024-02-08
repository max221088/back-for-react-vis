package BackupHelper;

use strict;
use warnings;

use SimpleFile;

sub new{
    my ($backup_helper, $path) = @_;

    my $self = {
        'backup_path' => $path,
    };

    bless $self, $backup_helper;

    return $self;
}

sub backup_path {
    my ($self, $id, $name) = @_;
    return SimpleFile->resolve_path($self->backup_folder($id), $name);
}

sub backup_folder {
    my ($self, $id) = @_;
    my $folder = SimpleFile->resolve_path($self->{backup_path}, $id);
    if (!-d $folder) {
        `mkdir $folder`;
    }
    return $folder;
}

sub get_sorted_backups {
    my ($self, $id) = @_;

    my $backup_folder = $self->backup_folder($id);
    my $lsRes = `ls $backup_folder | grep ^[0-9]\\.json`;
    my @files = sort {$a <=> $b} grep {$_} split(/\s+/, $lsRes);
    return @files;
}

sub create_backup {
    my ($self, $id, $content) = @_;
    my @backups = $self->get_sorted_backups($id);
    my $backup_length = scalar @backups;

    if ($backup_length == 0) {
        SimpleFile->write_file(
            $self->backup_path($id, "1.json"),
            $content
        );
    }
    elsif ($backup_length < 5) {
        my $backup_index = $backup_length + 1;
        SimpleFile->write_file(
            $self->backup_path($id, "$backup_index.json"),
            $content
        );
    }
    else {
        for my $backup (@backups) {
            $backup =~ /^(\d)/;
            if ($1 != 1) {
                my $backup_index = $1 - 1;
                SimpleFile->move_file(
                    $self->backup_path($id, $backup),
                    $self->backup_path($id, "$backup_index.json")
                );
            }
        }
        SimpleFile->write_file(
            $self->backup_path($id, "5.json"),
            $content
        );
    }
}

sub get_last_backup_name {
    my ($self, $id) = @_;
    my @backups = $self->get_sorted_backups($id);

    return pop @backups if scalar @backups > 0;
}

sub get_last_backup {
    my ($self, $id) = @_;
    my $last_backup_name = $self->get_last_backup_name($id);
    my $backup_path = $self->backup_path($id, $last_backup_name);

    return SimpleFile->read_json($backup_path) if defined $last_backup_name && -e $backup_path;
}

sub delete_last_backup {
    my ($self, $id) = @_;
    my $last_backup_name = $self->get_last_backup_name($id);

    SimpleFile->delete($self->backup_path($id, $last_backup_name)) if (defined $last_backup_name);
}

1;
