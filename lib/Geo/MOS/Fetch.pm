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
  
  my $resp = $ua->get('http://www.nws.noaa.gov/cgi-bin/mos/getmav.pl?sta=' . $location);

  if ($resp->is_success) {
    my $page     = $resp->decoded_content;
    my ($report) = $page =~ m#<PRE>\n(.+)\n</PRE>#s;
    return $report;
  }

  die "Failed response. " . $resp->as_string . "\n";
}

1;
