package Koha::Plugin::Fi::KohaSuomi::LabelPrinter;

use Modern::Perl;

use base qw( Koha::Plugins::Base );

use C4::Context;
use C4::Output qw( output_html_with_http_headers );

use Koha::DateUtils qw( dt_from_string );
use Koha::Virtualshelfcontent;
use Koha::Virtualshelves;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Fonts;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager;

use Data::Dumper;
use Mojo::JSON qw( decode_json );
use POSIX qw( strftime );
use Scalar::Util qw( blessed );
use Try::Tiny;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator;
#use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::Labels::UnknownItems;

our $VERSION = "1.0.10";
our $MINIMUM_VERSION = "22.05.00.000";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Koha-Suomi Label Printer',
    author          => 'Olli-Antti Kivilahti',
    date_authored   => '2014-01-30',
    date_updated    => "2023-04-13",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Koha-Suomi label printer',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}


## If your plugin needs to add some CSS to the staff intranet, you'll want
## to return that CSS here. Don't forget to wrap your CSS in <style>
## tags. By not adding them automatically for you, you'll have a chance
## to include external CSS files as well!
sub intranet_head {
    my ( $self ) = @_;

    return q|
        <style>
        </style>
    |;
}

## If your plugin needs to add some javascript in the staff intranet, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.
sub intranet_js {
    my ( $self ) = @_;

    return q|
        <script type="text/javascript">
        $(document).ready(function () {
            $("body#cat_additem form#f span#addmultiple").after('<div><input type="checkbox" name="addToPrintLabelsList" value="addToPrintLabelsList"/><label for="addToPrintLabelsList">Add to print label list</label></div>');
            $("body#cat_additem form#f").submit(function(event) {

                var op = $('input[name="op"]').val();
                if ( op !== "additem" ) {
                    return true;
                }
                var add_to_print_labels_list = false;
                if ( $('input[name="addToPrintLabelsList"]').prop('checked') ) {
                    add_to_print_labels_list = true;
                }

                if ( add_to_print_labels_list ) {
                    var f952x = $("input[id^='tag_952_subfield_x']");
                    var copies = $("#number_of_copies").val();

                    copies = parseInt(copies);
                    if (isNaN(copies)) {
                        copies = 0;
                    }

                    f952x.val("#add_to_print_labels_list_" + copies + "#" + f952x.val());
                }

            });
        });
        </script>
    |;
}

sub after_item_action {
    my ( $self, $params ) = @_;
    my $action  = $params->{action} // '';
    my $item    = $params->{item};
    my $item_id = $params->{item_id};

    if ( $action eq 'create' && defined $item->itemnotes_nonpublic && $item->itemnotes_nonpublic =~ /^#add_to_print_labels_list_(\d+)#/ ) {
        my $copies = $1;
        my $add_again = "";
        if ($copies > 1) {
            $copies--;
            $add_again = "#add_to_print_labels_list_$copies#";

            my $itemnotes = $item->itemnotes_nonpublic;
            $itemnotes =~ s/#add_to_print_labels_list_\d+#/$add_again/g;
            $itemnotes = undef if $itemnotes eq "";
            $item->set( { itemnotes_nonpublic => $itemnotes } );
            $item->store;
        } else {
            # clear add_to_print_labels_list_\d
            my $storage = $item->_result->result_source->storage;
            $storage->dbh_do(
                sub {
                    my ($storage, $dbh, @cols) = @_;

                    $dbh->do("UPDATE items SET itemnotes_nonpublic=REGEXP_REPLACE(itemnotes_nonpublic, ?, '') WHERE biblionumber=?", undef, '#add_to_print_labels_list_[0-9]+#', $item->biblionumber );
                }
            );
        }

        my $loggedinuser = C4::Context->userenv->{number};
        my $shelf = Koha::Virtualshelves->find( { owner => $loggedinuser, shelfname => 'labels printing'} );
        if (!$shelf) {
            $shelf = Koha::Virtualshelf->new( {
                shelfname => 'labels printing',
                owner => $loggedinuser,
                sortfield => undef,
                allow_change_from_owner => 1,
                allow_change_from_others => 0,
                } )->store;
        }
        my $content = Koha::Virtualshelfcontent->new(
                {
                    shelfnumber => $shelf->shelfnumber,
                    biblionumber => $item->biblionumber,
                    borrowernumber => $loggedinuser,
                    flags => $item->itemnumber,
                }
        )->store;
    }
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('label_sheets');

    return C4::Context->dbh->do( "
        CREATE TABLE IF NOT EXISTS $table ( -- stores Item label positioning and styling sheets in a condensed format
            `id`   int(11) NOT NULL, -- identifier for one branch of sheets. Can have many versions
            `name` varchar(100) NOT NULL,
            `author` int(11) DEFAULT NULL, -- biblionumber of the author who last modified this
            `version` float(4,1) NOT NULL, -- version of this sheet
            `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- latest modification time
            `sheet` MEDIUMTEXT NOT NULL, -- the monster sheet, containing item-slots, regions and elements
            KEY  (`id`),
            UNIQUE KEY `id_version` (`id`, `version`),
            KEY `name` (`name`),
            CONSTRAINT `labshet_authornumber` FOREIGN KEY (`author`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    " );
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('label_sheets');

    return C4::Context->dbh->do("DROP TABLE IF EXISTS $table");
}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    $self->tool_step1();

}

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};


    my $template_name = $args->{'file'} // '';
    # if not absolute, call mbf_path, which dies if file does not exist
    $template_name = $self->mbf_path( 'oplib-label-create.tt' )
        if $template_name !~ m/^\//;
    my ( $template, $loggedinuser, $cookie ) = C4::Auth::get_template_and_user(
        {   template_name   => $template_name,
            query           => $cgi,
            type            => "intranet",
            authnotrequired => 1,
        }
    );
    $template->param(
        CLASS       => $self->{'class'},
        METHOD      => scalar $self->{'cgi'}->param('method'),
        PLUGIN_PATH => $self->get_plugin_http_path(),
        PLUGIN_DIR  => $self->bundle_path(),
        LANG        => C4::Languages::getlanguage($self->{'cgi'}),
    );

    #JSONify the loggedinuser for javascript
    my $json = JSON::XS->new();
    my $loggedinuserJSON;
    if ($loggedinuser) {
        $loggedinuserJSON = $json->encode(Koha::Patrons->find({borrowernumber => $loggedinuser})->unblessed);
    }
    else {
        $loggedinuserJSON = $json->encode({});
    }

    $template->param( loggedinuserJSON  => $loggedinuserJSON );
    $template->param( dataSourceFunctions => $json->encode( Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager::getAvailableDataSourceFunctions() ) );
    $template->param( dataFormatFunctions => $json->encode( Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager::getAvailableDataFormatFunctions() ) );
    $template->param( fonts => Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Fonts::getAvailableFontsNicely() );

    my $op = $cgi->param('op') || ''; #operation code
    my $barcodes = $cgi->param('barcodes');
    unless ($barcodes) {
        $barcodes = [];
        my $items = getLabelPrintingListItems($loggedinuser);
        if (ref $items eq 'ARRAY') {
            foreach my $i (@$items) {
                push(@$barcodes, $i->{barcode});
                warn $i->{barcode};
            }
            $template->param(barcodesTextArea => join("\n",@$barcodes));
        }
    }
    my $marginsCookie = exists $cgi->{'.cookies'}->{'label_margins'} ? $cgi->{'.cookies'}->{'label_margins'} : $cgi->cookie(-name => 'label_margins', -value => '', -expires => '+3M');
    my $sheetId = $cgi->param('sheetId') || $marginsCookie->{value}->[2] || 0;

    #When we are using lableprinter by printing labels, we always get the leftMargin parameter, even when the input field is empty
    my $leftMargin = (defined($cgi->param('leftMargin')) ? $cgi->param('leftMargin') : $marginsCookie->{value}->[0] || 0);
    my $topMargin  = (defined($cgi->param('topMargin'))  ? $cgi->param('topMargin')  : $marginsCookie->{value}->[1] || 0);
    my $margins = {left => $leftMargin || 0, top => $topMargin || 0};
    $marginsCookie->{value}->[0] = $leftMargin;
    $marginsCookie->{value}->[1] = $topMargin;
    $marginsCookie->{value}->[2] = $sheetId;
    $template->param(margins => $margins);
    $template->param(sheetId => $sheetId);

    ##Barcodes have been submitted! How awesome!
    ##Separate the barcodes into an array and sanitate
    if ($barcodes) {
        #Sanitate the barcodes! Always sanitate input!! Mon dieu!
        $barcodes = [split( /\n/, $barcodes )] if $barcodes ne 'ARRAY';
        for(my $i=0 ; $i<@$barcodes ; $i++){
            $barcodes->[$i] =~ s/^\s*//; #Trim barcode for whitespace.
            $barcodes->[$i] =~ s/\s*$//; #Otherwise very hard to debug!?!!?!?!?
        }
    }

    if ($op eq "printLabels") {
        my $dir = '/tmp/';
        my $file = 'printLabel'.strftime('%Y%m%d%H%M%S',localtime).'.pdf';

        try {
            my $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheet($sheetId);
            my $creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => $margins, sheet => $sheet, file => $dir.$file});
            my $filePath = $creator->create($barcodes);

            my $filePathAndName = $dir.$file;
            sendPdf($cgi, $file, $filePathAndName, $marginsCookie, $cookie);
            return 1;

        } catch {
            if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::Labels::UnknownItems')) {
                $template->param('badBarcodeErrors', $_->badBunch);
                $template->param('barcode', $barcodes); #return barcodes if error happens!
                $template->param(barcodesTextArea => join("\n",@$barcodes)) if $barcodes;
            }
            else {
                $template->param('labelPrinterError', $_);
            }
        };
    }

    output_html_with_http_headers $cgi, $marginsCookie, $template->output;

    sub sendPdf {
        my ($cgi, $fileName, $filePathAndName, $marginsCookie, $cookie) = @_;
          #############################################
        ### Send the pdf to the user as an attachment ###
        print $cgi->header( -type       => 'application/pdf',
                            -cookie     => [$marginsCookie, $cookie],
                            -encoding   => 'utf-8',
                            -charset    => 'utf-8',
                            -attachment => $fileName,
                          ) if $marginsCookie;
        print $cgi->header( -type       => 'application/pdf',
                            -cookie     => [$cookie],
                            -encoding   => 'utf-8',
                            -charset    => 'utf-8',
                            -attachment => $fileName,
                          ) unless $marginsCookie;

        # slurp temporary filename and print it out for plack to pick up
        local $/ = undef;
        open(my $fh, '<', $filePathAndName) || die "$filePathAndName: $!";
        print <$fh>;
        close $fh;
        unlink $filePathAndName;
        ###              pdf sent hooray!             ###
          #############################################
    }

    sub getLabelPrintingListItems {
        my ($borrowernumber) = @_;
        my $dbh=C4::Context->dbh();
        my $query =
           "SELECT vc.*, i.*
             FROM virtualshelfcontents vc
             LEFT JOIN virtualshelves vs ON vs.shelfnumber = vc.shelfnumber
             LEFT JOIN items i ON i.itemnumber=vc.flags
             WHERE vc.borrowernumber=? AND vs.shelfname = 'labels printing' AND i.itemnumber IS NOT NULL";
        my @params = ($borrowernumber);
        my $sth3 = $dbh->prepare($query);
        $sth3->execute(@params);

        return $sth3->fetchall_arrayref({});
    }
}

sub _get_koha_version {
    my ($self) = @_;

    my $koha_version = C4::Context->preference('Version');
    $koha_version =~ s/\.//g;
    $koha_version = substr($koha_version, 0, 4); # this will be 2005, 2011, 2105 etc

    # returns Koha version as an integer, easy to compare
    return $koha_version;
}

## API methods
# If your plugin implements API routes, then the 'api_routes' method needs
# to be implemented, returning valid OpenAPI 2.0 paths serialized as a hashref.
# It is a good practice to actually write OpenAPI 2.0 path specs in JSON on the
# plugin and read it here. This allows to use the spec for mainline Koha later,
# thus making this a good prototyping tool.

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;

    return 'kohasuomi';
}

1;
