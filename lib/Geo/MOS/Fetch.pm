package Geo::MOS::Fetch;

use warnings;
use strict;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(timeout => 10);

sub new {
  my $class = shift;
  my %params = @_;
  my $self  = \%params;
  bless $self, $class;
  return $self;
}

sub fetch {
  my $self = shift;
  my $location = @_ ? shift : $self->{location};

  # Validate location
  unless ($location and $location =~ m/^(\w\w\w\w)$/) {
    die "Invalid location";
  }
  
  my $resp = $ua->get('https://www.weather.gov/source/mdl/MOS/GFSMAV.txt');

  my %forecasts = ();

  if ($resp->is_success) {
    my $page     = $resp->decoded_content;
    my $cur_sta;
    foreach my $line (split "\n", $page) {
      if ($line =~ m#^ (\w\w\w\w)   GFS MOS GUIDANCE#) {
        $cur_sta = $1;
      }
      $forecasts{$cur_sta} .= $line . "\n";
    }

    return $forecasts{$location};   
  }

  die "Failed response. " . $resp->as_string . "\n";
}

1;
