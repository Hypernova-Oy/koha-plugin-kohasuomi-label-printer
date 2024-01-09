package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Lists::Contents;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Mojo::Base 'Mojolicious::Controller';

use Koha::Virtualshelves;

sub add {
    my $c = shift->openapi->valid_input or return;

    try {
        my $body = $c->req->json;
        my $user = $c->stash('koha.user');
        unless ( $body->{borrowernumber} ){
            $body->{borrowernumber} = $user->borrowernumber;
        }

        if ($body->{listname} eq 'labels printing') {
            my $content = addDB($body->{borrowernumber}, $body->{itemnumber});
            return $c->render(status => 200, openapi => $content);
        } else {
            return $c->render( status => 400, openapi => {});
        }
    } catch {
        $c->unhandled_exception($_);
    };
}
sub delete {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->json;
    my $res = deleteDB($body->{borrowernumber});

    if ($res >= 0) {
        return $c->render( status => 200, openapi => {});
    } elsif ($res == 0) {
        return $c->render( status => 404, openapi => {});
    } else {
        return $c->render( status => 400, openapi => {});
    }
}

sub getDB {
    my ($id) = @_;

    my $dbh = C4::Context->dbh();
    my $label_table = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new->get_qualified_table_name('label_print_list');

    my @params;
    my $sql = "SELECT * FROM $label_table WHERE id = ?";

    my $sth = $dbh->prepare($sql);
    eval {
        $sth->execute( $id );
    };
    if ($@ || $sth->err) {
        my @cal = caller(0);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB->throw(error => $cal[3].'():>'.($@ || $sth->errstr));
    }
    return $sth->fetchrow_hashref();
}

sub listDB {
    my ($borrowernumber) = @_;

    my $dbh = C4::Context->dbh();
    my $label_table = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new->get_qualified_table_name('label_print_list');

    my @params;
    my $sql = "SELECT * FROM $label_table WHERE borrowernumber = ?";

    my $sth = $dbh->prepare($sql);
    eval {
        $sth->execute( $borrowernumber );
    };
    if ($@ || $sth->err) {
        my @cal = caller(0);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB->throw(error => $cal[3].'():>'.($@ || $sth->errstr));
    }
    my @rows = $sth->fetchrow_hashref();
    return \@rows;
}

sub addDB {
    my ($borrowernumber, $itemnumber) = @_;

    my $dbh = C4::Context->dbh();
    my $label_table = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new->get_qualified_table_name('label_print_list');

    my @params;
    my $sql = "INSERT INTO $label_table (borrowernumber, itemnumber) VALUES (?, ?)";

    my $sth = $dbh->prepare($sql);
    eval {
        $sth->execute( $borrowernumber, $itemnumber );
    };
    if ($@ || $sth->err) {
        my @cal = caller(0);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB->throw(error => $cal[3].'():>'.($@ || $sth->errstr));
    }
    return getDB($sth->{mysql_insertid});
}

sub deleteDB {
    my ($borrowernumber) = @_;

    my $dbh = C4::Context->dbh();
    my $label_table = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new->get_qualified_table_name('label_print_list');

    my @params;
    my $sql = "DELETE FROM $label_table WHERE borrowernumber = ?";

    my $sth = $dbh->prepare($sql);
    eval {
        return $sth->execute( $borrowernumber );
    };
    if ($@ || $sth->err) {
        my @cal = caller(0);
        Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::DB->throw(error => $cal[3].'():>'.($@ || $sth->errstr));
    }
}

1;
