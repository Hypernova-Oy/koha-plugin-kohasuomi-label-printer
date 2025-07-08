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
  '24.11.02' => \&v24_11_02,
  '24.11.04' => \&v24_11_04,
);

sub upgrade {
  my ($plugin, $args) = @_;
  eval {

  my $installedVersion = _getInstalledVersion($plugin);
  $log->info("Checking for upgrades from version '$installedVersion' to latest version '".$plugin->{metadata}->{version}."'");

  unless (_getUpgradeLock($plugin)) {
    $log->info("PID:'$$'. Failed to acquire upgrade lock. Yielding the upgrade process to some other process.");
    return 1; # returning 0 would raise an error in the plugin system
  }

  for my $upgradePackage ( sort keys %upgrades ) {
    if ( version->parse($upgradePackage) > version->parse($installedVersion) ) {
      &{$upgrades{$upgradePackage}}($plugin, $args);
      $log->info("Upgrade package done for plugin version '$upgradePackage'");
      $upgradesDone{$upgradePackage} = 1;
      $plugin->store_data({'__INSTALLED_VERSION__' => $upgradePackage});
    }
  }

  $plugin->store_data({'__INSTALLED_VERSION__' => $plugin->{metadata}->{version}});
  $log->info("Plugin upgraded to version '".$plugin->{metadata}->{version}."'");

  my $dt = dt_from_string();
  $plugin->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

  };
  if ($@) {
    $log->error("Upgrade failed: $@");
    return 0;
  }

  _releaseUpgradeLock($plugin);

  return 1;
}

sub _getInstalledVersion {
  my ($plugin) = @_;
  my $installedVersion = $plugin->retrieve_data('__INSTALLED_VERSION__');
  if (not($installedVersion)) {
      $log->logdie("Plugin installedVersion '".($installedVersion || 'undef').'\' not defined! Expected re/\d+\.\d+\.\d+/');
  }
  if (not($installedVersion =~ /^\d+\.\d+\.\d+$/)) {
      $log->logdie("Plugin installedVersion '".($installedVersion || 'undef').'\' malformed! Expected re/\d+\.\d+\.\d+/');
  }
  return $installedVersion;
}

sub _getUpgradeLock {
  my ($plugin) = @_;
  my $dbh = C4::Context->dbh;
  my $lockTimeout = 0; # seconds
  my $lockAcquired = $dbh->selectrow_hashref("SELECT GET_LOCK(?, ?) as 'locked'", undef, _getUpgradeLockName($plugin), $lockTimeout);
  unless ($lockAcquired->{locked}) {
    $log->debug("PID:'$$'. Failed to acquire upgrade lock '"._getUpgradeLockName($plugin)."'. Another upgrade might be in progress or the lock is not available.");
    return undef;
  }
  $log->debug("PID:'$$'. Acquired upgrade lock '"._getUpgradeLockName($plugin)."'");
  return 1;
}

sub _releaseUpgradeLock {
  my ($plugin) = @_;
  my $dbh = C4::Context->dbh;
  my $lockReleased = $dbh->selectrow_hashref("SELECT RELEASE_LOCK(?) as 'released'", undef, _getUpgradeLockName($plugin));
  unless ($lockReleased->{released}) {
    $log->error("PID:'$$'. Failed to release upgrade lock '"._getUpgradeLockName($plugin)."'.");
    return undef;
  }
  $log->debug("PID:'$$'. Released upgrade lock '"._getUpgradeLockName($plugin)."'");
  return 1;
}

sub _getUpgradeLockName {
  my ($plugin) = @_;
  return C4::Context->config('database').".".$plugin->{metadata}->{name}.".upgrade_lock";
}

sub v24_11_02 {
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

sub v24_11_04 { # Important to use non-class code here, as sometime in the future when the upgrade is ran, the object classes might not be suitable with old data formats.
  my ($plugin) = @_;

  my $ratio = 2.877619048;
  my $convertPixelsToMillimeters = sub {
    my ($objectName, $dim, $pos) = @_;
    $log->info("Converting pixel dimensions (".$dim->{width}.",".$dim->{height}.") and position (".($pos && defined($pos->{left}) ? $pos->{left} : '').",".($pos && defined($pos->{top}) ? $pos->{top} : '').") to millimeters with ratio $ratio");
    $dim->{width} = sprintf("%.1f", $dim->{width} / $ratio);
    $dim->{height} = sprintf("%.1f", $dim->{height} / $ratio);
    $pos->{left} = sprintf("%.1f", $pos->{left} / $ratio) if $pos && $pos->{left};
    $pos->{top} = sprintf("%.1f", $pos->{top} / $ratio) if $pos && $pos->{top};
  };

  if (my $sheetVersions = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::listSheetVersions($plugin)) {
    for my $sheetVersion (@$sheetVersions) {
      # The programming API for Sheets might be out of sync with the database contents, so safer to use primitives access for guaranteed future upgradability.
      my $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheetFromDB($plugin, $sheetVersion->{id});
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
