
do 'mysql-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
if ($cgi eq 'list_vars.cgi') {
	# Works with no args
	return '';
	}
elsif ($cgi eq 'edit_dbase.cgi' || $cgi eq 'backup_form.cgi' ||
       $cgi eq 'exec_form.cgi') {
	# Use default DB
	return 'db=mysql';
	}
elsif ($cgi eq 'table_form.cgi') {
	return 'db=mysql&fields=4';
	}
elsif ($cgi eq 'edit_view.cgi') {
	return 'db=mysql&new=1';
	}
elsif ($cgi eq 'edit_table.cgi' || $cgi eq 'view_table.cgi') {
	return 'db=mysql&table=user';
	}
elsif ($cgi eq 'edit_field.cgi') {
	return 'db=mysql&table=user&idx=0';
	}
return undef;
}
