package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade;

use Modern::Perl;
use strict;
use warnings;
use version;

use C4::Context;
use Koha::DateUtils qw( dt_from_string );

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager;

use Koha::Logger;
use Log::Log4perl::Level;
our $log = Koha::Logger->get({category => __PACKAGE__});
$log->{logger}->level($DEBUG);

our %upgradesDone;
our %upgrades = (
  '0.0.1' => \&v001,
  '0.0.4' => \&v004,
);

sub upgrade {
  my ($plugin, $args) = @_;

  my $installedVersion = _getInstalledVersion($plugin);

  for my $upgradePackage ( sort keys %upgrades ) {
    if ( version->parse($upgradePackage) > version->parse($installedVersion) ) {
      &{$upgrades{$upgradePackage}}($plugin, $args);
      $log->info("Upgraded plugin to version $upgradePackage");
      $upgradesDone{$upgradePackage} = 1;
      $plugin->store_data({'__INSTALLED_VERSION__' => $upgradePackage});
    }
  }

  my $dt = dt_from_string();
  $plugin->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

  return 1;
}

sub _getInstalledVersion {
  my ($plugin) = @_;
  my $installedVersion = $plugin->retrieve_data('__INSTALLED_VERSION__');
  if (not($installedVersion)) {
      $log->logdie("Plugin installedVersion '".($installedVersion || 'undef').'\' not defined! Expected re/\d+\.\d+\.\d+/');
  }
  elsif ($installedVersion =~ /^\d\d\.\d\d\.\d+$/) {
    $log->info("Plugin installedVersion '$installedVersion' is in old format, converting to new format.");
    return '0.0.1';
  }
  if (not($installedVersion =~ /^\d+\.\d+\.\d+$/)) {
      $log->logdie("Plugin installedVersion '".($installedVersion || 'undef').'\' malformed! Expected re/\d+\.\d+\.\d+/');
  }
  return $installedVersion;
}

sub v001 {
  my ($plugin) = @_;
  my $table_print_list = $plugin->get_qualified_table_name('label_print_list');

  my $dbh = C4::Context->dbh;
  $dbh->do("
    CREATE TABLE IF NOT EXISTS $table_print_list ( -- stores Items added to the print list, for easy printing
      `id`   int(11) NOT NULL AUTO_INCREMENT,
      `itemnumber` int(11) NOT NULL,
      `borrowernumber` int(11) NOT NULL,
      `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- latest modification time
      PRIMARY KEY  (`id`),
      CONSTRAINT `labshetprlist_itemnumber` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT `labshetprlist_borrowernumber` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ") or die($dbh->errstr());
}

sub v004 {
  my ($plugin) = @_;

  my $ratio = 2.877619048;
  my $convertPixelsToMillimeters = sub {
    my ($objectName, $dim, $pos) = @_;
    $log->info("Converting pixel dimensions (".$dim->{width}.",".$dim->{height}.") and position (".($pos && defined($pos->{left}) ? $pos->{left} : '').",".($pos && defined($pos->{top}) ? $pos->{top} : '').") to millimeters with ratio $ratio");
    $dim->{width} /= $ratio;
    $dim->{height} /= $ratio;
    $pos->{left} /= $ratio if $pos && $pos->{left};
    $pos->{top} /= $ratio if $pos && $pos->{top};
  };

  if (my $sheetVersions = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::listSheetVersions()) {
    for my $sheetVersion (@$sheetVersions) {
      # The programming API for Sheets might be out of sync with the database contents, so safer to use primitives access for guaranteed future upgradability.
      my $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheetFromDB($sheetVersion->{id});
      $sheet = JSON::XS->new()->decode($sheet->{sheet});

      next if ($sheet->{schema});

      $log->info("Sheet ".$sheet->{name}." (".$sheetVersion->{id}.") v".$sheetVersion->{version}." upgrading to schema version 1");
      $sheet->{schema} = 1;

      &$convertPixelsToMillimeters("Sheet".$sheetVersion->{id}."v".$sheetVersion->{version}, $sheet->{dimensions}, $sheet->{position});

      if (my $items = $sheet->{items}) {
        for my $item (@$items) {
          if (my $regions = $item->{regions}) {
            for my $region (@$regions) {

              &$convertPixelsToMillimeters("Region".$region->{id}, $region->{dimensions}, $region->{position});

              if (my $elements = $region->{elements}) {
                for my $element (@{$elements}) {
                  &$convertPixelsToMillimeters("Item".$item->{index}, $element->{dimensions}, $element->{position});
                }
              }
            }
          }
        }
      }
      Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::_updateSheetJSONToDB($plugin, $sheetVersion->{id}, $sheetVersion->{version}, $sheet);
      $log->info("Sheet ".$sheet->{name}." (".$sheetVersion->{id}.") v".$sheetVersion->{version}." upgraded to schema version 1");
    }
  }

  return 1;
}
