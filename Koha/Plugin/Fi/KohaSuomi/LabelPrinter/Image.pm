package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Image;

# Copyright 2025 Hypernova Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use warnings;

use Koha::Exceptions;

sub new { my ($class, $jpgPathOrDataBase64) = @_;
  my $data = _getDataFromPathOrData($jpgPathOrDataBase64);
  my $self = bless({data => $data}, $class);
  ($self->{width}, $self->{height}) = $self->getJpgDimensions();
  return $self;
}

sub data {return $_[0]->{data}}
sub width {return $_[0]->{width}}
sub height {return $_[0]->{height}}

sub getJpgDimensions { my ($self) = @_;
  # Thanks claude.ai
  # Extract width and height
  # Look for SOF0 marker (0xFFC0)
  if ($self->data =~ /\xFF[\xC0\xC1\xC2\xC3\xC5\xC6\xC7\xC9\xCA\xCB\xCD\xCE\xCF].{3}(.{2})(.{2})/s) {
      my $height = unpack('n', $1);
      my $width = unpack('n', $2);
      return ($width, $height);
  }
  return (undef, undef);
}

sub _getDataFromPathOrData { my ($jpgPathOrData) = @_;
  my $imgData;
  if (-e $jpgPathOrData) {
    open(my $fh, '<:raw', $jpgPathOrData) or die($!);
    $imgData = do { local $/; <$fh> };
    close($fh);
  }
  else {
    $imgData = $jpgPathOrData;
  }
  isValidBase64($imgData); #dies
  $imgData = MIME::Base64::decode_base64($imgData);
  return $imgData;
}

sub isValidBase64 { my ($string) = @_; # claude.io
  my $logDataShortened = (length($string) > 50) ? substr($string, 0, 50).'...' : $string;
  my @cc = caller(0);

  # Remove whitespace (Base64 can have line breaks)
  $string =~ s/\s+//g;
  # Empty string is technically valid Base64
  unless(defined $string && length $string) {
    Koha::Exceptions::BadParameter->throw(error => $cc[3]."():> Image data base64 validity check - given data '$logDataShortened' is empty.");
  }
  # Check if length is multiple of 4 (Base64 requirement)
  unless(length($string) % 4 == 0) {
    Koha::Exceptions::BadParameter->throw(error => $cc[3]."():> Image data base64 validity check - given data '$logDataShortened' is not of multiples of 4.");
  }
  # Check if it only contains valid Base64 characters
  # Valid: A-Z, a-z, 0-9, +, /, and = for padding
  unless($string =~ /^[A-Za-z0-9+\/]*={0,2}$/) {
    Koha::Exceptions::BadParameter->throw(error => $cc[3]."():> Image data base64 validity check - given data '$logDataShortened' contains invalid characters.");
  }
  # Check padding is only at the end
  if($string =~ /=[^=]/) {
    Koha::Exceptions::BadParameter->throw(error => $cc[3]."():> Image data base64 validity check - given data '$logDataShortened' has bad padding '==='. Expected to find it only at the end of the data.");
  }
  return 1;
}

1;
