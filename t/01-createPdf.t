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
  $ENV{KOHA_LOG_LEVEL} = 'TRACE';
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

use JSON::XS;

use Test::More tests => 2;
use Test::Deep;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter;

$Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator::log->level('TRACE');

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

my $testFile = '/tmp/test.pdf';

my $testBarcodes = [
  'SAO00105858',
  '0103013605',
];

subtest("Scenario: Render the sheet #2.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  $barcodes = $testBarcodes;
  plan tests => 4;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  $margins = {
    top => 0,
    left => 0,
    right => 0,
    bottom => 0,
  };
  ok($margins, "Given margins");

  $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheet(2);
  ok($sheet, "And a Sheet");

  ok($barcodes, "And some barcodes");

  subtest("When a PDF is created", sub {
    plan tests => 2;
    ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => $margins, sheet => $sheet, file => $testFile.'2'}), "A PDF creator is created");
    ok($filePath = $creator->create($barcodes), "A PDF is created");
  });
});

subtest("Scenario: Update a sheet.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  $barcodes = $testBarcodes;
  plan tests => 8;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  my $sheetJSON = <<JSON;
  {
    "name": "Testi",
    "dpi": "100",
    "id": "3",
    "grid": "19.7",
    "dimensions": {
      "width": 456,
      "height": 413
    },
    "version": "0.4",
    "author": {
      "userid": "hypernova.kivilahtio",
      "borrowernumber": 1
    },
    "timestamp": "2025-04-30T07:39:41",
    "boundingBox": true,
    "items": [
      {
        "index": 1,
        "regions": [
          {
            "id": 43,
            "cloneOfId": null,
            "dimensions": {
              "width": 120,
              "height": 76
            },
            "position": {
              "left": 25,
              "top": 27.2667
            },
            "boundingBox": false,
            "elements": [
              {
                "id": 300140,
                "dimensions": {
                  "width": 30,
                  "height": 30
                },
                "position": {
                  "left": 26,
                  "top": 15.6333
                },
                "boundingBox": true,
                "dataSource": "\\"TESTI\\"",
                "dataFormat": "oneLiner",
                "fontSize": 12,
                "font": "H",
                "customAttr": "",
                "colour": {
                  "r": 0,
                  "g": 0,
                  "b": 0,
                  "a": 1
                }
              }
            ]
          }
        ]
      },
      {
        "index": 2,
        "regions": [
          {
            "id": 45,
            "cloneOfId": 43,
            "dimensions": {
              "width": 120,
              "height": 76
            },
            "position": {
              "left": 103.7,
              "top": 105.967
            },
            "boundingBox": false,
            "elements": []
          }
        ]
      }
    ]
  }
JSON
  my $sheetHash = JSON::XS->new()->decode($sheetJSON);

  $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet->new($sheetHash);
  ok($sheet, "Given a Sheet");

  my $sourceRegion = $sheet->getRegionById(43);
  ok($sourceRegion, "Which has a source region");
  is($sourceRegion->getCloneOfId(), 0, "Which has no cloneOfId");

  my $clonedRegion = $sheet->getRegionById(45);
  ok($clonedRegion, "Which has a cloned region");
  is($clonedRegion->getCloneOfId(), 43, "Which has a cloneOfId");

  ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => undef, sheet => $sheet, file => $testFile}), "A PDF creator is created");
  ok($filePath = $creator->create($barcodes), "A PDF is created");
  is($filePath, $testFile, "The PDF is created in the correct location");
});

$schema->storage->txn_rollback;

1;