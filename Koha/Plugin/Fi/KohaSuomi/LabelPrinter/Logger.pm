package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Logger;

our $LOG4PERL_INTERFACE = 'plugins';
our $LOG4PERL_PREFIX = 0;

use Koha::Logger;
use Log::Log4perl::Level;

=head2 USAGE

Put this to your log4perl config file

log4perl.logger.Koha::Plugin::Fi::KohaSuomi::LabelPrinter = TRACE, PLUGINS
log4perl.logger.plugins.Koha::Plugin::Fi::KohaSuomi::LabelPrinter = TRACE, PLUGINS
log4perl.appender.PLUGINS=Log::Log4perl::Appender::File
log4perl.appender.PLUGINS.filename=/var/log/koha/production_urjala/plugins.log
log4perl.appender.PLUGINS.mode=append
log4perl.appender.PLUGINS.layout=PatternLayout
log4perl.appender.PLUGINS.layout.ConversionPattern=[%d] [%p] %m%n
log4perl.appender.PLUGINS.utf8=1

then touch the log file and set the correct permissions

touch /var/log/koha/*/plugins.log
chown koha:koha /var/log/koha/*/plugins.log

=cut

sub get { my ($class) = @_;
  return Koha::Logger->get({prefix => $LOG4PERL_PREFIX, interface => $LOG4PERL_INTERFACE, category => caller()});
}

1;
