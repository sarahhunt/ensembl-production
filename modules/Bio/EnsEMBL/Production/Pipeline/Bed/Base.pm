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

=cut

package Bio::EnsEMBL::Production::Pipeline::Bed::Base;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;
use File::Spec;
use Bio::EnsEMBL::Utils::Exception qw/throw/;

sub assert_executable {
	my ($self, $key, $exe) = @_;
	$exe //= $key;
	throw "No ${exe} executable given" unless $self->param_is_defined($key);
  return $self->SUPER::assert_executable($self->param($key));
}

sub data_path {
  my ($self) = @_;
  $self->throw("No 'species' parameter specified")
    unless $self->param('species');
  return $self->get_dir('bed', $self->param('species'));
}

# Always set to Homo_sapiens.GRCh37.chrom.sizes (no reason not to)
sub chrom_sizes_file {
  my ($self) = @_;
  return $self->generate_file_name('chrom.sizes');
}

sub generate_file_name {
  my ($self, $file_type, @additional_parts) = @_;

  # File name format looks like:
  # <species>.<assembly>.<additional>.<filetype>

  my @name_bits;
  push @name_bits, $self->web_name();
  push @name_bits, $self->assembly();
  push @name_bits, @additional_parts;
  push @name_bits, $file_type;

  my $file_name = join( '.', @name_bits );
  my $path = $self->data_path();

  return File::Spec->catfile($path, $file_name);
}

=head2 get_name_from_Slice

For a Slice, look at the internal seq region cache for a hit. If it does not
exist find any UCSC synonyms if available and if not add if the magic chr onto
the start

=cut

sub get_name_from_Slice {
	my ($self, $slice) = @_;
	
	my $cache = $self->_get_seq_region_cache();

	my $seq_region_name = $slice->seq_region_name();
	return $cache->{$seq_region_name} if exists $cache->{$seq_region_name};

	my $ucsc_name;
  my $has_adaptor = ($slice->adaptor()) ? 1 : 0;
  if($has_adaptor) { # if it's got an adaptor we can lookup synonyms
    my $synonyms = $slice->get_all_synonyms('UCSC');
    if(@{$synonyms}) {
      $ucsc_name = $synonyms->[0]->name();
    }
  }
  if(! defined $ucsc_name) {
    # if it's a chromosome then we can test a few more things
    if($slice->is_chromosome()) {
      #MT is a special case; it's chrM
      if($seq_region_name eq 'MT' ) {
        $ucsc_name = 'chrM';
      }
      # If it was a ref region add chr onto it (only check if we have an adaptor)
      elsif($has_adaptor && $slice->is_reference()) {
        $ucsc_name = 'chr'.$seq_region_name;
      }
    }
  }
  #Leave it as the seq region name otherwise
  $ucsc_name = $seq_region_name if ! defined $ucsc_name;
  $cache->{$seq_region_name} = $ucsc_name;
  return $ucsc_name;
}

sub _get_seq_region_cache {
	my ($self) = @_;
	my $cache;
	if(! $self->param_is_defined('seq_region_cache')) {
		$cache = $self->param('seq_region_cache', {});
	}
	else {
		$cache = $self->param('seq_region_cache');
	}
	return $cache;
}

1;