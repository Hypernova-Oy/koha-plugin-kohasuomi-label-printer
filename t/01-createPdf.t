#!/usr/bin/env perl

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

BEGIN {
  $ENV{LOG4PERL_VERBOSITY_CHANGE} = 6;
  $ENV{MOJO_OPENAPI_DEBUG} = 1;
  $ENV{MOJO_LOG_LEVEL} = 'debug';
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
}

use Modern::Perl;
use strict;
use warnings;
use utf8;

use Test::More tests => 1;
use Test::Deep;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

subtest("Scenario: Render the sheet #3.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  plan tests => 4;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  $margins = {
    top => 0,
    left => 0,
    right => 0,
    bottom => 0,
  };
  ok($margins, "Given margins");

  $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheet(3);
  ok($sheet, "And a Sheet");

  $barcodes = [
    'SAO00105858',
  ];
  ok($barcodes, "And some barcodes");

  subtest("When a PDF is created", sub {
    plan tests => 2;
    ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => $margins, sheet => $sheet, file => '/tmp/test.pdf'}), "A PDF creator is created");
    ok($filePath = $creator->create($barcodes), "A PDF is created");
  });
});

$schema->storage->txn_rollback;

1;