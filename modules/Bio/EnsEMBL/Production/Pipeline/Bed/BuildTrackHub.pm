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

package Bio::EnsEMBL::Production::Pipeline::Bed::BuildTrackHub;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::IO qw/work_with_file slurp/;
use File::Spec;
use Cwd;

use base qw/Bio::EnsEMBL::Production::Pipeline::Bed::Base/;

my $genomes_file_name = 'genomes.txt';

my $track_hub_template = <<'DOC';
hub ensemblHub
shortLabel Ensembl genome annotation
longLabel A collection of large files providing genome annotation from the Ensembl project
genomesFile %s
email helpdesk@ensembl.org
DOC

my $genome_template = <<'DOC';
genome %s
trackDb %s

DOC

sub fetch_input {
  my ($self) = @_;
  $self->throw("Need a base_path") unless $self->param_is_defined('base_path');
  return;
}

sub write_output {
	my ($self) = @_;
	$self->_write_hub_file();
	$self->_write_genomes_file();
	$self->_write_track_db_file();
}

sub _write_hub_file {
	my ($self) = @_;
	my $file = File::Spec->catfile($self->raw_data_path(), 'TrackHub.txt');
	work_with_file($file, 'w', sub {
		my ($fh) = @_;
		printf $fh $track_hub_template, $genomes_file_name;
		return;
	});
	return;
}

sub _write_genomes_file {
	my ($self) = @_;
	my $file = File::Spec->catfile($self->raw_data_path(), $genomes_file_name);
	work_with_file($file, 'w', sub {
		my ($fh) = @_;
		foreach my $species (keys %{$self->param_required('input_species')}) {
			my $ucsc_name = $self->_ucsc_name($species);
			my $track_db_file = $self->_track_db_file($species);

			# This is how we do some quick relative pathing!
			my $dir = getcwd();
			chdir($self->raw_data_path());
			my $rel_file_path = File::Spec->abs2rel($track_db_file);
			chdir($dir);
	
			# And print
			printf $fh $genome_template, $ucsc_name, $rel_file_path;
		}
		return;
	});
	return;
}

sub _write_track_db_file {
	my ($self) = @_;
	foreach my $species (keys %{$self->param_required('input_species')}) {
		my $target_trackdb_file = $self->_track_db_file($species);
		work_with_file($target_trackdb_file, 'w', sub {
			my ($fh) = @_;
			warn $species;
			my $production_name = $self->production_name($species);
			my @tracks = map {$_->{def}} grep { $_->{species} eq $production_name } @{$self->param_required('track')};
			foreach my $track (@tracks) {
				my $content = slurp($track);
				print $fh $content;
				print $fh "\n";
			}	
			return;
		});
	}
	return;
}

sub _track_db_file {
	my ($self, $species) = @_;
	my $data_dir = $self->data_path($species);
	my $track_db_file = File::Spec->catfile($data_dir, 'trackDb.txt');
	return $track_db_file;
}

sub _ucsc_name {
	my ($self, $species) = @_;
	my $prod_name = $self->production_name($species);
	my $assembly = $self->assembly($species);
	my $lookup = { 
		homo_sapiens 	=> { GRCh37 => 'hg19', 		GRCh38 	=> 'hg38' },
		mus_musculus 	=> { NCBI37 => 'mm9',			GRCm38 	=> 'mm10' },
		danio_rerio		=> { Zv8		=>'danRer6',	Zv9			=> 'danRer7' },
	};
	if(exists $lookup->{$prod_name} && exists $lookup->{$prod_name}->{$assembly}) {
		return $lookup->{$prod_name}->{$assembly};
	}
	return $assembly;
}

1;