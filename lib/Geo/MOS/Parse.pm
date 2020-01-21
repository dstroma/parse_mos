package Geo::MOS::Parse;

use warnings;
use strict;
use DateTime;
use feature 'say';

=sample

my $sample = <<HDOC;
 KFYJ   GFS MOS GUIDANCE    9/13/2019  1200 UTC                      
 DT /SEPT 13/SEPT 14                /SEPT 15                /SEPT 16 
 HR   18 21 00 03 06 09 12 15 18 21 00 03 06 09 12 15 18 21 00 06 12 
 N/X                    65          83          69          84    67 
 TMP  73 72 67 67 67 66 68 77 81 80 74 72 71 71 72 79 82 81 73 69 71 
 DPT  67 67 66 65 65 65 67 70 70 71 73 71 70 71 72 71 69 69 72 69 71 
 CLD  OV OV OV OV OV OV OV OV BK BK BK OV OV OV OV OV OV BK BK SC BK 
 WDR  08 08 08 09 09 09 10 12 14 13 12 13 14 12 00 31 03 10 10 00 00 
 WSP  08 08 05 03 02 01 01 04 05 06 04 02 01 01 00 02 04 03 02 00 00 
 P06        15     6     3    15     8     8    13    28    31 11  7 
 P12                    20          15          16          39    16 
 Q06         0     0     0     0     0     0     0     0     0  0  0 
 Q12                     0           0           0           0     0
 T06     05/11 01/ 2  0/ 1  1/ 2  8/ 3  1/ 1  0/ 0  0/ 0  2/ 8  0/ 0
 T12            7/11        1/ 2        8/ 4        0/ 1     2/ 8 
 POZ   0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 
 POS   0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 
 TYP   R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R 
 SNW                     0                       0                 0 
 CIG   4  5  5  5  5  5  6  5  6  6  6  6  6  3  3  5  6  7  8  8  7 
 VIS   7  7  7  7  7  7  7  7  7  7  7  7  2  1  2  7  7  7  7  7  1 
 OBV   N  N  N  N  N  N  N  N  N  N  N  N FG FG BR  N  N  N  N  N FG 
HDOC

# T06      1/ 0  0/ 0  0/ 0  4/ 0  1/ 0  3/ 0  3/ 0 15/ 0 22/ 7  1/ 0 
# T12            1/ 0        4/ 1        3/ 0       19/ 4    22/ 7    


my $forecast = Geo::MOS::Parse->new(plaintext => $sample);
$forecast->_parse;
#warn $forecast->generation_time->iso8601();
#delete $forecast->{generation_time};
#use Data::Dumper;
#warn Dumper $forecast, "\n";
print $forecast->report;

=cut

###############################################################################

sub new {
  my $class = shift;
  my %params = @_;
  my $self  = \%params;
  bless $self, $class;
  return $self;
}

sub plaintext {
  my $self = shift;
  $self->{plaintext} = shift if @_;
  return $self->{plaintext};
}

sub parsed {
  my $self = shift;
  $self->_parse unless $self->{'_parsed?'};
  return $self;
}

sub copy {
  my $self = shift;
  require Storable;
  return Storable::dclone $self;
}

sub flattened {
  my $self = shift;
  my $flat = $self->copy;
  foreach my $col ($flat->{columns}->@*) {
    $col->{datetime} = $col->{datetime}->iso8601;
  }
  return $flat;
}

#sub as_json {
#  require JSON::MaybeXS;
#  foreach my $col ($self->{columns}->@*) {
#    $col->{datetime} = $col->{datetime}->iso8601;
#  }
#} 

sub _parse {
  my $self = shift;

  return 1 if $self->{'_parsed?'};
  $self->{'_parsed?'} = 1;

  my @rows = split '\n', $self->{plaintext};
  #$self->{'_plaintext::rows'} = @rows;
  my $header = $rows[0];

  my ($loc, $label, $month, $day, $year, $hour, $minute) = $header =~ m#(\w\w\w\w)\s+(GFS MOS GUIDANCE)\s+(\d{1,2})/(\d\d)/(\d\d\d\d)\s+(\d\d)(\d\d) UTC#;
  $self->{location} = $loc;
  $self->{forecast_type} = $label;
  $self->{generation_time} = DateTime->new(
    year => $year, month => $month, day => $day, hour => $hour, minute => $minute, second => 0, time_zone => 'UTC'
  );

  my $hour_header = $rows[2];
  ($hour_header) = $hour_header =~ m/HR\s+(.+)/;
  my (@hours) = split /\s+/, $hour_header;
  #my %hours = map { $_ => {} } @hours;

  my @hours_detail = ();
  my $current_date = DateTime->from_object(object => $self->generation_time);
  foreach my $h (@hours) {

    # Determine the forecast datetime
    my $maybe_forecast_datetime = DateTime->from_object(object => $current_date);
    $maybe_forecast_datetime->set_hour($h);
    if ($maybe_forecast_datetime < $current_date) {
      $maybe_forecast_datetime->add(days => 1);
    }

    push @hours_detail, {
      hour => $h,
      datetime => $maybe_forecast_datetime,
    };

    $current_date = DateTime->from_object(object => $maybe_forecast_datetime);
  }

  #$self->{hour_list} = \@hours;
  #$self->{hours}      = [ map { { hour => $_ } } @hours ];
  $self->{columns} = \@hours_detail;

  # Parse rows 4-21 except 13 and 14
  for (my $i = 4; $i <= 21; $i++) {
    my $row = $rows[$i];                   # Get i'th row
    $row =~ s/^\s+//;                      # Remove leading whitespace
    my $label = substr($row, 0, 3);        # Label is first 3 chars of row
    $row = substr($row, 5);                # Remove first column
    for (my $j = 0; $j <= 20; $j++) {      # Loop through 20 columns
      my $val;
      if ($label eq 'T06' or $label eq 'T12') {    # Double-width columns
        next unless $j >= 2 and $j % 2 == 0;
        $val = substr($row, $j*3 - 3, 5);          # Extract 5-character column
      } else {
        $val = substr($row, ($j*3)-1, 3);              # Extract 3-character column
      }
      $val =~ s/^\s+//;                    # Remove leading whitespace
      $self->{columns}->[$j]->{$label} = $val if length $val;

      # Change T06, P06 from previous 6 hours to next 6 hours
      if ($label eq 'P06' and length $val) {
        my $label2 = $label . '_future';
        my $six_hours_ago = $self->{columns}[$j]{hour} - 6;
        $six_hours_ago += 24 if $six_hours_ago < 0;
        #warn "$label Hour is " . $self->{columns}[$j]{hour} . " and six hours ago was $six_hours_ago";
        my $colno;
        if ($self->{columns}->[$j-1]->{hour} == $six_hours_ago) {
          $colno = $j - 1;
        } elsif ($self->{columns}->[$j-2]->{hour} == $six_hours_ago) {
          $colno = $j - 2;
        } else {
          die 'WTF!'
        }
        $self->{columns}[$colno]{$label2} = $val;
      }
    }
  }
}


sub f_to_c {
  ($_[0] - 32) / 1.8;
}

###############################################################################
# Getters

sub generation_time { return shift->{generation_time}; }

###############################################################################
# Formatters

sub report {
  my $self   = shift;
  my %params = @_;

  $self->_parse;

  my @text = ();

  my %CLD_key = (
    OV => 'Overcast',
    BK => 'Broken',
    SC => 'Scattered',
    FW => 'Few',
    CL => 'Clear'
  );

  my %CIG_key = (
    1 => 'Less than 200 feet',
    2 => '200-400 feet',
    3 => '500-900 feet',
    4 => '1,000-1,900 feet',
    5 => '2,000-3,000 feet',
    6 => '3,100-6,500 feet',
    7 => '6,600-12,000 feet',
    8 => 'Above 12,000 feet'
  );

  my %VIS_key = (
    1 => 'Less than 1/2 mile',
    2 => '1/2 to 1 mile',
    3 => '1 to 2 miles',
    4 => '2 to 3 miles',
    5 => '3 to 5 miles',
    6 => '6 miles',
    7 => 'Greater than 6 miles',
  );

  my %OBV_key = (
    HZ => 'Haze, smoke, or dust',
    BR => 'Mist',
    FG => 'Fog',
    BL => 'Bowing dust, sand, or snow'
  );

  my %TYP_key = ( 
    S => 'Snow',
    Z => 'Freezing Precipitation',
    R => 'Rain'
  );

  push @text, 'Report for ' . $self->{location} . ' generated ' . $self->generation_time->ymd . ' ' . $self->generation_time->hms;  
  foreach my $col ($self->{columns}->@*) {

    my $sky = $CLD_key{$col->{CLD}};
    if ($col->{CLD} ne 'CL') {
      $sky .= ' with bases ' . lc $CIG_key{$col->{CIG}};
    }

    my $wind = 'Calm';
    if ($col->{WSP} > 0) {
      $wind = $col->{WDR} . '0 @ ' . int($col->{WSP}) . ' kts.';
    }

    my $vis = $VIS_key{$col->{VIS}};
    if (exists $OBV_key{$col->{OBV}}){
      $vis .= ' in ' . lc $OBV_key{$col->{OBV}};
    }

    my $tstorm_desc;
    if (exists $col->{T06}) {
      my ($tstorm, $sev_tstorm) = map { int $_ } split('/', $col->{T06});
      $tstorm_desc = $tstorm . '% chance';
      $tstorm_desc .= ' (' . $sev_tstorm . '% of which may be severe) ' if $sev_tstorm > 0;
      $tstorm_desc .= ' within the previous 6 hours';
    }

    if ($params{'timezone'}) {
      $col->{datetime}->set_time_zone($params{'timezone'});
    }

    push @text, uc($col->{datetime}->strftime('%a %b %d at %I:%M %p')) . ":";
    push @text, "\tTemperature: " . $col->{TMP} . '°F';
    push @text, "\tDewpoint:    " . $col->{DPT} . '°F';
    push @text, "\tSky:         " . $sky;
    push @text, "\tVisibility:  " . $vis;
    push @text, "\tWind:        " . $wind;
    #push @text, "\tPrecip:      " . $col->{P06} . '% chance of ' . lc $TYP_key{$col->{TYP}} . ' within the previous 6 hours' if exists $col->{P06};
    push @text, "\tPrecip:      " . $col->{P06_future} . '% chance within the next 6 hours' if exists $col->{P06_future};
    #push @text, "\tT-Storm:     " . $tstorm_desc if $tstorm_desc;
    push @text, '';
  }

  return join "\n", @text;
}


1;
