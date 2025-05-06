package t::Lib;

use strict;
use warnings;

use JSON::XS;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region;

sub mockRegion {
  return Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region->new(
    {
        id => 1,
        name => 'Region 1',
        x => 0,
        y => 0,
        width => 100,
        height => 100,
        elements => [],
    }
  );
}

sub mockSheet {
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
              "height": 70
            },
            "position": {
              "left": 10,
              "top": 10
            },
            "boundingBox": false,
            "elements": [
              {
                "id": 300140,
                "dimensions": {
                  "width": 60,
                  "height": 30
                },
                "position": {
                  "left": 5,
                  "top": 5
                },
                "boundingBox": true,
                "dataSource": "\\"TESTI1\\"",
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
              },
{
                "id": 300140,
                "dimensions": {
                  "width": 60,
                  "height": 30
                },
                "position": {
                  "left": 5,
                  "top": 5
                },
                "boundingBox": true,
                "dataSource": "\\"TESTI2\\"",
                "dataFormat": "oneLiner",
                "fontSize": 12,
                "font": "H",
                "customAttr": "center=1",
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

  return Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet->new($sheetHash);
}

1;
