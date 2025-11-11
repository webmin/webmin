# phpini-monitor.pl
# Monitor a FPM-FPM server

sub get_phpini_status
{
my ($serv, $mod) = @_;
return { 'up' => -1 } if (!&foreign_check("phpini"));
return { 'up' => -1 } if (!&foreign_check("init"));
&foreign_require("phpini");
my @files = &phpini::list_php_configs();
my ($file) = grep { $_->[0] eq $serv->{'inifile'} } @files;
return { 'up' => -1,
	 'desc' => $text{'phpini_nofile'} } if (!$file);
my $init = &phpini::get_php_ini_bootup($serv->{'inifile'});
return { 'up' => -1,
	 'desc' => $text{'phpini_noinit'} } if (!$init);
&foreign_require("init");
my $st = &init::status_action($init);
if ($st < 0) {
	return { 'up' => -1,
		 'desc' => &text('phpini_noinit2', $init) };
	}
elsif ($st > 0) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0,
		 'desc' => &text('phpini_downinit', $init) };
	}
}

sub show_phpini_dialog
{
my ($serv) = @_;
&foreign_require("phpini");
my @files = grep { $_->[1] }
		 map { [ $_->[0], &phpini::get_php_ini_version($_->[0]) ||
				  &phpini::get_php_binary_version($_->[0]) ] }
		     &phpini::list_php_configs();
my %donever;
@files = grep { !$donever{$_->[1]}++ } @files;
print &ui_table_row($text{'phpini_file'},
	&ui_select("inifile", $serv->{'inifile'}, \@files));
}

sub parse_phpini_dialog
{
my ($serv) = @_;
$in{'inifile'} || &error($text{'phpini_efile'});
$serv->{'inifile'} = $in{'inifile'};
}

