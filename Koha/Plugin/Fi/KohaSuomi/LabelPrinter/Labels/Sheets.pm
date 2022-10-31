package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Labels::Sheets;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);
use IO::File;
use JSON qw( from_json );

use Mojo::Base 'Mojolicious::Controller';

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet;

use Koha::Exceptions;

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sheetRows = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheetsFromDB();

        if (@$sheetRows > 0) {
            my @sheets;
            foreach my $sheetRow (@$sheetRows) {
                push @sheets, $sheetRow->{sheet};
            }
            return $c->render(status => 200, openapi => \@sheets);
        }
        else {
            return $c->render( status  => 404,
                           openapi => { error => "Sheets not found" } );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

sub create {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $s = $c->validation->param('sheet');
        my $sheetHash = JSON::XS->new()->decode($s);
        my $user = $c->stash('koha.user');
        $sheetHash->{'author'} = {
            'userid' => $user->userid,
            'borrowernumber' => $user->borrowernumber,
        };
        my $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet->new($sheetHash);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::putNewSheetToDB($sheet);
        return $c->render(status => 201, openapi => $sheet->toJSON());
    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::BadParameter')) {
            return $c->render(status => 400, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);

    };
}

sub update {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $s = $c->validation->param('sheet');
        my $sheetHash = JSON::XS->new()->decode($s);
        my $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet->new($sheetHash);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::putNewVersionToDB($sheet);
        return $c->render(status => 201, openapi => $sheet->toJSON());
    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::BadParameter')) {
            return $c->render(status => 400, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Exceptions::ObjectNotFound')) {
            return $c->render(status => 404, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);
    };
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $id = $c->validation->param('sheet_identifier');
        my $version = $c->validation->param('sheet_version');
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::deleteSheet($id, $version);
        return $c->render( status => 204, openapi => {});
    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::ObjectNotFound')) {
            return $c->render(status => 404, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);
    };
}

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $id = $c->validation->param('sheet_identifier');
        my $version = $c->validation->param('sheet_version');
        my $sheetRow = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheetFromDB( $id, '', $version );

        if ($sheetRow) {
            return $c->render( status => 200, openapi => $sheetRow->{sheet});
        }
        else {
            return $c->render( status  => 404,
                           openapi => { error => "Sheet not found" } );
        }
    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::ObjectNotFound')) {
            return $c->render(status => 404, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);
    };
}

sub import_file {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $filename;
        my $path = '/tmp/';
        for my $file ($c->req->upload('file')) {
            $filename = $file->filename;
            $file->move_to($path.$filename);
        }
        my $fh = IO::File->new("$path$filename", "r");
        my $content;
        if (defined $fh) {
            $content = <$fh>;
            $fh->close;
            my $ok = eval {from_json($content)};
            if ($ok) {
               return $c->render( status => 201, openapi => $content);
            } else {
                return $c->render( status  => 404,
                           openapi => { error => "Wrong file content!" } );
            }
        }

    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::BadParameter')) {
            return $c->render(status => 400, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);
    };
}

sub list_sheet_versions {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sheetMetaData = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::listSheetVersions();
        my @sheetMetaData = map {Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::swaggerizeSheetVersion($_)} @$sheetMetaData if ($sheetMetaData && ref($sheetMetaData) eq 'ARRAY');

        if (scalar(@sheetMetaData)) {
            return $c->render(status => 200, openapi => \@sheetMetaData);
        }
        else {
            Koha::Exceptions::ObjectNotFound->throw(error => "No sheets found");
        }
    } catch {
        if (blessed($_) && $_->isa('Koha::Exceptions::ObjectNotFound')) {
            return $c->render(status => 404, json => { error => $_->error });
        }
        if (blessed($_) && $_->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        $c->unhandled_exception($_);
    };
}

1;
