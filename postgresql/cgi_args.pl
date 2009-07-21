
do 'postgresql-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
my $db;
eval {
	local $main::error_must_die = 1;
	($db) = grep { &can_edit_db($_) &&
		       !/^template/ } &list_databases();
	};
return undef if (!$db);	# Don't know which DB to use
if ($cgi eq 'edit_dbase.cgi' || $cgi eq 'backup_form.cgi' ||
    $cgi eq 'exec_form.cgi' || $cgi eq 'restore_form.cgi') {
	# Use first DB
	return 'db='.&urlize($db);
	}
elsif ($cgi eq 'list_grants.cgi') {
	# Works with no args
	return '';
	}
elsif ($cgi eq 'table_form.cgi') {
	return 'db='.&urlize($db).'&fields=4';
	}
elsif ($cgi eq 'edit_view.cgi' || $cgi eq 'edit_seq.cgi') {
	return 'db='.&urlize($db).'&new=1';
	}
elsif ($cgi eq 'edit_table.cgi' || $cgi eq 'edit_field.cgi' ||
       $cgi eq 'view_table.cgi') {
	# Find a table
	my $table;
	eval {
		local $main::error_must_die = 1;
		($table) = &list_tables($db);
		};
	return 'db='.&urlize($db).'&table='.&urlize($table).
	       ($cgi eq 'edit_field.cgi' ? '&idx=0' : '');
	}
return undef;
}
