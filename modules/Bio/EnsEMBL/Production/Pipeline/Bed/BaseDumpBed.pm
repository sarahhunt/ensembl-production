=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at L<http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  L<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Bed::BaseDumpBed

=head1 DESCRIPTION

The main workhorse of the Bed dumping pipeline. Implemneted as a templated 
class so you must provide the type of dumper and any additional work to 
seralise your objects into BED.

Allowed parameters are:

=over 8

=item species - The species to dump

=item base_path - The base of the dumps

=item group - The database group to dump from

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::BaseDumpBed;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Production::Pipeline::Bed::Base);

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;
use File::Basename qw/basename/;

sub param_defaults {
  return {
    group => 'core',
    write_track_def => 1,
  };
}

sub fetch_input {
  my ($self) = @_;
  $self->SUPER::fetch_input();
  $self->param('type', $self->type());
  return;
}

sub run {
  my ($self) = @_;

  my $type = $self->type();
  my $path = $self->generate_file_name();
  $self->info("Dumping %s BED to %s", $type, $path);
  work_with_file($path, 'w', sub {
    my ($fh) = @_;
    my $sorted_slices = $self->get_bed_Slices();
    while (my $slice = shift @{$sorted_slices}) {
      my $features = $self->get_Features($slice);
      while( my $feature = shift @{$features}) {
        $self->write_Feature($fh, $feature);
      }
    }
  }); 
  $self->param('bed', $path);
  $self->write_track_def();
  $self->write_autosql();
  $self->param('bed_type', $self->get_bed_type());
  $self->param('bigbed_indexes', $self->get_bigbed_indexes());
  return;
}

# Specify the type of dump we are doing
sub type {
  my ($self) = @_;
  $self->throw('Please implement type()');
}

# Return the features from the Slice. Always sort
sub get_Features {
  my ($self, $slice) = @_;
  $self->throw('Please implement get_Features()');
}

sub get_track_def {
  my ($self) = @_;
  $self->throw('Please implement get_track_def()');
}

sub get_autosql {
  my ($self) = @_;
  $self->throw('Please implement get_autosql()');
}

sub get_bed_type {
  my ($self) = @_;
  $self->throw('Please implement get_bed_type()');
}

# Returns the fields that should be indexed by BigBed
sub get_bigbed_indexes {
  return [];
}

# Returns slices sorted by name
sub get_bed_Slices {
  my ($self) = @_;
  my $slices;
  if($self->param_is_defined('locations') && @{$self->param('locations')}) {
    $slices = [];
    my $sa = $self->get_DBAdaptor('core')->get_SliceAdaptor();
    foreach my $location (@{$self->param('locations')}) {
      push(@{$slices}, $sa->fetch_by_toplevel_location($location));
    }
  }
  else {
    $slices = $self->get_Slices($self->param('group'), 1);
  }

  my @sorted_slices = 
      map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [$_, $self->get_name_from_Slice($_)] } 
      @{$slices};

  return \@sorted_slices;
}

# Convert a feature to a BED array and then write it out to the file handle
sub write_Feature {
  my ($self, $fh, $feature) = @_;
  return unless $feature;
  my $bed_array = $self->feature_to_bed_array($feature);
  my $bed_line = join("\t", @{$bed_array});
  print $fh $bed_line, "\n";
  return 1;
}

# Call the method get_track_def() which returns the track config
# and then write it out to a file. We then set the file path as
# param('def')
sub write_track_def {
  my ($self) = @_;
  return unless $self->param('write_track_def');
  my $file = $self->generate_track_def_file_name();
  work_with_file($file, 'w', sub {
    my ($fh) = @_;
    my $track_name = basename($self->param('bed'));
    $track_name =~ s/\.bed$//;
    my $big_bed_file = $track_name.'.bb';
    print $fh $self->get_track_def($track_name, $big_bed_file);
    return;
  });
  $self->param('def', $file);
  return;
}

# Call and write the AutoSql def out to a file. All should have one (it's better that way)
sub write_autosql {
  my ($self) = @_;
  my $autosql_path = $self->generate_autosql_file_name();
  work_with_file($autosql_path, 'w', sub {
    my ($fh) = @_;
    my $autosql = $self->get_autosql();
    print $fh $autosql;
    return;
  });
  $self->param('autosql', $autosql_path);
  return;
}

sub feature_to_bed_array {
  my ($self, $feature) = @_;
  return $self->_feature_to_bed_array($feature);
}

# Convert a feature to a BED array (6 values by default to capture strand)
sub _feature_to_bed_array {
  my ($self, $feature) = @_;
  my $chr_name = $self->get_name_from_Slice($feature->slice());
  my $start = $feature->seq_region_start() - 1;
  my $end = $feature->seq_region_end();
  my $strand = ($feature->seq_region_strand() == -1) ? '-' : '+';
  my $display_id = $feature->display_id();
  return [ $chr_name, $start, $end, $display_id, 0, $strand ];
}

# Converts a feature to a bed array and then puts in the associcated score (not everything has a score)
sub scored_feature_to_bed_array {
  my ($self, $feature) = @_;
  my $bed_array = $self->_feature_to_bed_array($feature);
  my $score = $feature->score();
  $score = 0 if $score < 0;
  $score = 1000 if $score > 1000;
  $bed_array->[4] = $score;
  return $bed_array;
}

# File name format looks like:
# <species>.<assembly>.<type>.<additional>.bed
# e.g. Homo_sapiens.GRCh37.transcripts.2013-04.bed
# e.g. Homo_sapiens.GRCh37.repeats.bed
sub generate_file_name {
  my ($self, @additional_parts) = @_;
  return $self->SUPER::generate_file_name('bed', $self->type(), @additional_parts);
}

# Generate the normal name but sub .def for .bed
sub generate_track_def_file_name {
  my ($self, @additional_parts) = @_;
  my $file = $self->generate_file_name(@additional_parts);
  $file =~ s/\.bed$/.def/;
  return $file;
}

# Generate the normal name but sub .as for .bed
sub generate_autosql_file_name {
  my ($self, @additional_parts) = @_;
  my $file = $self->generate_file_name(@additional_parts);
  $file =~ s/\.bed$/.as/;
  return $file;
}

1;
