#!/usr/bin/perl
# Tests the SQLite CGIs with an isolated Webmin configuration.

use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path getcwd);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use IPC::Open3;
use MIME::Base64 ();
use Symbol qw(gensym);

my $driver_error;
eval { require DBI; require DBD::SQLite; };
$driver_error = $@;
# Treat a driver without result-limit control as unavailable to CGI tests.
if (!$driver_error && !DBD::SQLite::db->can('sqlite_limit')) {
	$driver_error = 'DBD::SQLite does not provide sqlite_limit';
	}
# CGI integration tests require a real driver with result-limit control.
plan skip_all => "DBD::SQLite unavailable or incompatible: $driver_error"
	if ($driver_error);

# Create isolated Webmin configuration, state and database directories.
my $module_dir = abs_path(File::Spec->catdir($FindBin::Bin, '..'));
my $root = abs_path(File::Spec->catdir($module_dir, '..'));
my $temp = tempdir(CLEANUP => 1);
my $config_dir = File::Spec->catdir($temp, 'config');
my $var_dir = File::Spec->catdir($temp, 'var');
my $data_dir = File::Spec->catdir($temp, 'data');
my $fake_lib = File::Spec->catdir($temp, 'fake-lib');
my $old_driver_lib = File::Spec->catdir($temp, 'old-driver-lib');
make_path(File::Spec->catdir($config_dir, 'sqlite'),
	File::Spec->catdir($config_dir, 'software'),
	File::Spec->catdir($fake_lib, 'DBD'),
	File::Spec->catdir($old_driver_lib, 'DBD'), $var_dir, $data_dir);

# Every page, configuration and ACL help topic must ship with the module.
foreach my $topic (qw(
	intro database table create column exec edit_row acl_info config_intro
	config_recent config_perpage config_max_text config_busy_timeout
	config_max_query_rows config_max_result_bytes config_confirm_delete
	delete_rows drop_column drop_table
	)) {
	ok(-f File::Spec->catfile($module_dir, 'help', $topic.'.html'),
		"$topic help topic is installed");
	}

# sub write_text(path, content)
# Writes one configuration or test data file.
sub write_text
{
my ($path, $content) = @_;
open(my $fh, '>', $path) or die "open $path: $!";
print {$fh} $content;
close($fh) or die "close $path: $!";
}

# sub sqlite_alter_supported_in_test(feature)
# Mirrors the module's version gate for column renames (SQLite 3.25) and
# drops (3.35), so the tests expect what the installed library can do.
sub sqlite_alter_supported_in_test
{
my ($feature) = @_;
my %needs = ( 'rename_column' => 3025000, 'drop_column' => 3035000 );
no warnings 'once';
return $DBD::SQLite::sqlite_version_number >= $needs{$feature} ? 1 : 0;
}

# Give one test administrator full access to the fixture directory.
write_text(File::Spec->catfile($config_dir, 'config'),
	"os_type=debian-linux\nos_version=13\nlang=en\n");
write_text(File::Spec->catfile($config_dir, 'miniserv.conf'),
	"root=$root\nmimetypes=$root/mime.types\n");
write_text(File::Spec->catfile($config_dir, 'webmin.acl'),
	"admin: sqlite software cpan\n");
write_text(File::Spec->catfile($config_dir, 'sqlite', 'config'),
	"perpage=1\nmax_text=1000\nbusy_timeout=100\n".
	"max_query_rows=100\nmax_result_bytes=1048576\nconfirm_delete=1\n");
# An unrestricted test ACL lets older local SQLite versions exercise CGI
# behavior; the path-boundary tests restore a restricted ACL later.
write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=/\nwrite=1\ncreate=1\nsql=1\n");
write_text(File::Spec->catfile($config_dir, 'software', 'config'),
	"package_system=debian\nupdate_system=apt\napt_mode=0\n");
write_text(File::Spec->catfile($fake_lib, 'DBD', 'SQLite.pm'),
	"die \"DBD::SQLite disabled for this test\\n\";\n");
# Load the real driver in a child process but hide sqlite_limit to simulate an
# older distribution package without reimplementing the DBI driver interface.
my $real_driver = $INC{'DBD/SQLite.pm'};
$real_driver =~ s/([\\'])/\\$1/g;
write_text(File::Spec->catfile($old_driver_lib, 'DBD', 'SQLite.pm'),
	"do '$real_driver' or die \$\@ || \$!;\n".
	"no warnings 'once';\n".
	"undef *DBD::SQLite::db::sqlite_limit;\n".
	"1;\n");

# Populate tables for pagination, empty-state, long text, oversized text and
# BLOB checks.
my $database = File::Spec->catfile($data_dir, 'sample.db');
my $dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
$dbh->do('CREATE TABLE sample (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
$dbh->do("INSERT INTO sample (name) VALUES ('first'), ('second')");
$dbh->do('CREATE TABLE empty_sample (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->do('CREATE TABLE long_sample (id INTEGER PRIMARY KEY, record TEXT)');
my $long_text = 'x' x 2222;
$dbh->do('INSERT INTO long_sample (record) VALUES (?)', undef, $long_text);
my $oversized_text = 'y' x 1049000;
$dbh->do('INSERT INTO long_sample (record) VALUES (?)', undef,
	$oversized_text);
$dbh->do('CREATE TABLE blob_sample (id INTEGER PRIMARY KEY, data BLOB)');
my $blob_insert = $dbh->prepare(
	'INSERT INTO blob_sample (data) VALUES (?)');
$blob_insert->bind_param(1, 'ascii blob', DBI::SQL_BLOB());
$blob_insert->execute();
$dbh->disconnect();

# Create a database whose schema metadata exceeds the request result budget.
my $oversized_schema_database = File::Spec->catfile($data_dir,
	'oversized-schema.db');
$dbh = DBI->connect('dbi:SQLite:dbname='.$oversized_schema_database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my $oversized_default = 's' x 1049000;
$dbh->do("CREATE TABLE oversized_schema (id INTEGER PRIMARY KEY, ".
	"payload TEXT DEFAULT '$oversized_default')");
$dbh->disconnect();

# sub url_encode(value)
# Encodes one query-string or form value.
sub url_encode
{
my ($value) = @_;
# Treat an omitted scalar like an empty form value.
$value = '' if (!defined($value));
my $bytes = $value;
# Percent-encode the UTF-8 bytes, not Perl's character representation.
utf8::encode($bytes) if (utf8::is_utf8($bytes));
$bytes =~ s/([^A-Za-z0-9._~-])/sprintf('%%%02X', ord($1))/ge;
return $bytes;
}

# sub form_body(values)
# Serializes scalar and repeated form values.
sub form_body
{
my ($form) = @_;
my @pairs;
foreach my $key (sort keys %$form) {
	my @values = ref($form->{$key}) eq 'ARRAY' ?
		@{$form->{$key}} : ($form->{$key});
	push(@pairs, map { url_encode($key).'='.url_encode($_) } @values);
	}
return join('&', @pairs);
}

# sub run_cgi(script, method, values, [extra-library-directory], [options])
# Runs one SQLite CGI in the isolated Webmin environment. The script is a
# CGI name in the module directory, or an absolute path to a test helper.
# The optional library directory is prepended to Perl's search path. Options
# may add environment variables ('env') and name the script as another
# module's CGI would ('script_name').
sub run_cgi
{
my ($script, $method, $values, $extra_lib, $options) = @_;
$options ||= {};
my $body = form_body($values || {});
my $in_module = $script !~ m!^/!;
my %env = (
	'PATH' => '/bin:/usr/bin',
	'WEBMIN_CONFIG' => $config_dir,
	'WEBMIN_VAR' => $var_dir,
	'FOREIGN_MODULE_NAME' => 'sqlite',
	'FOREIGN_ROOT_DIRECTORY' => $root,
	'MINISERV_CONFIG' => File::Spec->catfile($config_dir, 'miniserv.conf'),
	'REMOTE_USER' => 'admin',
	'BASE_REMOTE_USER' => 'admin',
	'REQUEST_METHOD' => $method,
	'SCRIPT_NAME' => $options->{'script_name'} || '/sqlite/'.$script,
	'SCRIPT_FILENAME' => $in_module ?
		File::Spec->catfile($module_dir, $script) : $script,
	'SERVER_NAME' => 'localhost',
	'SERVER_PORT' => '10000',
	'HTTP_HOST' => 'localhost:10000',
	%{ $options->{'env'} || {} },
	);
# GET requests carry their form body in the query string.
if ($method eq 'GET') {
	$env{'QUERY_STRING'} = $body;
	}
else {
	# Other methods send the same encoded body through standard input.
	$env{'CONTENT_TYPE'} = 'application/x-www-form-urlencoded';
	$env{'CONTENT_LENGTH'} = length($body);
	}

my $cwd = getcwd();
chdir($module_dir) or die "chdir $module_dir: $!";
my $err = gensym();
local %ENV = %env;
my @command = ($^X);
# An optional leading library path simulates a missing or broken dependency.
push(@command, '-I'.$extra_lib) if ($extra_lib);
push(@command, '-I'.$root, $in_module ? './'.$script : $script);
my $pid = open3(my $in, my $out, $err, @command);
# Supply a request body only for methods that read standard input.
if ($method ne 'GET') {
	print {$in} $body;
	}
close($in);
local $/;
my $stdout = <$out> // '';
my $stderr = <$err> // '';
close($out);
close($err);
waitpid($pid, 0);
my $status = $? >> 8;
chdir($cwd) or die "chdir $cwd: $!";
return { 'status' => $status, 'out' => $stdout, 'err' => $stderr };
}

# Check the database selector and its standard controls.
my $index = run_cgi('index.cgi', 'GET', {});
is($index->{'status'}, 0, 'index CGI exits successfully');
is($index->{'err'}, '', 'index CGI emits no warnings');
like($index->{'out'}, qr/SQLite Database Browser/,
	'index CGI renders the module title');
like($index->{'out'}, qr/SQLite version \d+\.\d+[\d.]* \(DBD::SQLite \d/,
	'index CGI shows the library and driver versions under the title');
like($index->{'out'}, qr{/config\.cgi\?module=sqlite},
	'index CGI offers the standard module configuration link');
unlike($index->{'out'}, qr/\bui_section_title\b/,
	'index CGI shows no recent list before a database was opened');
like($index->{'out'}, qr/\bui_card\b/,
	'index CGI frames the open form in a card');
like($index->{'out'}, qr/>Open a database</,
	'index CGI titles the form for a first database');
unlike($index->{'out'}, qr/\bui_table\b/,
	'index CGI does not split the picker controls into table columns');
unlike($index->{'out'}, qr/\bui_segmented\b|name="create"/,
	'index CGI has no file mode switch, since a missing file is created when allowed');
like($index->{'out'}, qr/Webmin creates the file if it does not exist/,
	'index CGI tells users who may create files that a missing file is created');
like($index->{'out'}, qr/<label\b[^>]*\bfor="db"[^>]*>Path on server<\/label>/,
	'index CGI labels the database path field');
like($index->{'out'}, qr/name="db"[^>]*placeholder=['"]\/var\/lib\/myapp\/data\.db['"]/,
	'index CGI shows an example path in the field');
like($index->{'out'}, qr/\bui_field_help\b/,
	'index CGI explains the path under the field');
like($index->{'out'}, qr/<button\b(?=[^>]*\bui_action_primary\b)(?=[^>]*\btype="submit")[^>]*>/,
	'index CGI submits the form with a primary action button');

# Opening a path that does not exist creates the database when allowed.
my $new_database = File::Spec->catfile($data_dir, 'fresh.db');
my $opened_new = run_cgi('open.cgi', 'POST', { 'db' => $new_database });
is($opened_new->{'status'}, 0, 'open CGI exits successfully for a new file');
is($opened_new->{'err'}, '', 'open CGI emits no warnings for a new file');
like($opened_new->{'out'}, qr/^Location: .*database\.cgi\?db=/mi,
	'open CGI creates a missing database and opens it');
ok(-f $new_database, 'the new database file exists');

# Check native Debian dependency installation.
my $missing_driver = run_cgi('index.cgi', 'GET', {}, $fake_lib);
is($missing_driver->{'status'}, 0,
	'index CGI exits successfully when the SQLite driver is missing');
is($missing_driver->{'err'}, '',
	'index CGI emits no warnings when the SQLite driver is missing');
like($missing_driver->{'out'}, qr{/software/install_pack\.cgi},
	'index CGI offers native package installation through Software Packages');
like($missing_driver->{'out'}, qr/libdbi-perl libdbd-sqlite3-perl/,
	'index CGI requests the Debian SQLite driver packages');
like($missing_driver->{'out'},
	qr/The required Perl module <tt\b[^>]*>DBD::SQLite<\/tt>\s+could not be loaded/,
	'index CGI names the missing module in a plain sentence');
unlike($missing_driver->{'out'}, qr/\bui_page\b|\bui_card\b|\bui_alert\b|name="db"/,
	'index CGI shows nothing but the message and installer without the driver');

# Switch package managers and check the RPM package names.
write_text(File::Spec->catfile($config_dir, 'software', 'config'),
	"package_system=rpm\nupdate_system=yum\n");
my $missing_rpm_driver = run_cgi('index.cgi', 'GET', {}, $fake_lib);
is($missing_rpm_driver->{'status'}, 0,
	'index CGI exits successfully with the RPM package installer');
is($missing_rpm_driver->{'err'}, '',
	'index CGI emits no warnings with the RPM package installer');
like($missing_rpm_driver->{'out'}, qr{/software/install_pack\.cgi},
	'index CGI offers RPM installation through Software Packages');
like($missing_rpm_driver->{'out'}, qr/perl-DBI perl-DBD-SQLite/,
	'index CGI requests the RPM SQLite driver packages');

# An installed driver without sqlite_limit needs an upgrade, not another
# installation of the same native package.
my $old_driver = run_cgi('index.cgi', 'GET', {}, $old_driver_lib);
is($old_driver->{'status'}, 0,
	'index CGI exits successfully with an incompatible SQLite driver');
is($old_driver->{'err'}, '',
	'index CGI emits no warnings with an incompatible SQLite driver');
like($old_driver->{'out'},
	qr/DBD::SQLite \S+ is installed, but it cannot safely limit result data/,
	'index CGI explains why the installed driver is incompatible');
# Use Webmin's CPAN installer when that optional module is available. Otherwise,
# tell the administrator to update the driver outside Webmin.
if (-d File::Spec->catdir($root, 'cpan')) {
	like($old_driver->{'out'}, qr{/cpan/download\.cgi},
		'index CGI offers a CPAN upgrade for an incompatible driver');
	like($old_driver->{'out'},
		qr/name="cpan"[^>]*value="DBD::SQLite"/,
		'index CGI asks CPAN to update DBD::SQLite');
	}
else {
	# Without the optional CPAN module, provide manual upgrade instructions.
	unlike($old_driver->{'out'}, qr{/cpan/download\.cgi},
		'index CGI omits an unavailable CPAN installer');
	like($old_driver->{'out'},
		qr/Update DBD::SQLite to version 1\.62 or later/,
		'index CGI gives manual driver upgrade instructions');
	}
unlike($old_driver->{'out'}, qr{/software/install_pack\.cgi},
	'index CGI does not offer to reinstall the same native package');
my $old_driver_database = run_cgi('database.cgi', 'GET', {
	'db' => $database }, $old_driver_lib);
is($old_driver_database->{'status'}, 1,
	'database CGI refuses an incompatible SQLite driver');
like($old_driver_database->{'out'},
	qr/DBD::SQLite \S+ does not provide sqlite_limit/,
	'direct database access reports the missing driver capability');

# Verify that each CGI renders a Webmin error page for oversized metadata.
my $oversized_database_page = run_cgi('database.cgi', 'GET', {
	'db' => $oversized_schema_database });
is($oversized_database_page->{'status'}, 1,
	'database CGI uses Webmin error handling for oversized metadata');
like($oversized_database_page->{'out'},
	qr/result exceeds the configured 1048576-byte limit/i,
	'database CGI shows the metadata size error');
my $oversized_table_page = run_cgi('table.cgi', 'GET', {
	'db' => $oversized_schema_database, 'table' => 'oversized_schema' });
is($oversized_table_page->{'status'}, 1,
	'table CGI uses Webmin error handling for oversized metadata');
like($oversized_table_page->{'out'},
	qr/result exceeds the configured 1048576-byte limit/i,
	'table CGI shows the metadata size error');
my $oversized_editor_page = run_cgi('edit_row.cgi', 'GET', {
	'db' => $oversized_schema_database, 'table' => 'oversized_schema',
	'new' => 1 });
is($oversized_editor_page->{'status'}, 1,
	'row editor uses Webmin error handling for oversized metadata');
like($oversized_editor_page->{'out'},
	qr/result exceeds the configured 1048576-byte limit/i,
	'row editor shows the metadata size error');

# Check database summary cards and object-table wrapping.
my $database_page = run_cgi('database.cgi', 'GET', { 'db' => $database });
is($database_page->{'status'}, 0, 'database CGI exits successfully');
is($database_page->{'err'}, '', 'database CGI emits no warnings');
like($database_page->{'out'}, qr/sample/,
	'database CGI lists the sample table');
like($database_page->{'out'}, qr/data-sortable=['"]1['"]/,
	'database CGI explicitly makes the object list sortable');
my @database_cards = $database_page->{'out'} =~
	/<section\b[^>]*class="[^"]*\bui_card\b[^"]*"/g;
is(scalar(@database_cards), 4,
	'database CGI renders database details as four bordered cards');
like($database_page->{'out'}, qr{/unauthenticated/css/ui-lib\.css\?},
	'database CGI loads the widget stylesheet');
unlike($database_page->{'out'}, qr/&lt;span data-filesize-bytes=/,
	'database CGI renders the formatted database size as HTML');
like($database_page->{'out'}, qr/aria-label="This database does not use write-ahead logging/,
	'database CGI keeps the WAL guidance in a compact help tooltip');
like($database_page->{'out'}, qr/font-size: 1\.48em/,
	'database CGI reduces the metric value size for this module');
like($database_page->{'out'}, qr/<a [^>]*style="display:inline-block;white-space:nowrap;"[^>]*>sample<\/a>/,
	'database CGI keeps linked object names on one line');
like($database_page->{'out'},
	qr/<tt\b(?=[^>]*style="white-space:normal;overflow-wrap:anywhere;")[^>]*>CREATE TABLE/,
	'database CGI allows schema definitions to wrap');

# Opening a database puts it on the front page's recent list.
my $recent_file = File::Spec->catfile($config_dir, 'sqlite', 'recent', 'admin');
ok(-f $recent_file, 'database CGI records the opened file per Webmin user');
my $recent_index = run_cgi('index.cgi', 'GET', {});
is($recent_index->{'status'}, 0,
	'index CGI exits successfully with a recent list');
is($recent_index->{'err'}, '', 'index CGI emits no warnings with a recent list');
like($recent_index->{'out'}, qr/\bui_section_title_text\b[^>]*>Recent</,
	'index CGI heads the recent list with a section title');
like($recent_index->{'out'}, qr/<a\b(?=[^>]*\bhref="forget_recent\.cgi\?db=)(?=[^>]*\bui_action_small\b)[^>]*>.*?>Remove</s,
	'index CGI offers a small button to forget an entry');
unlike($recent_index->{'out'}, qr/clear_recent|Clear list/,
	'index CGI has no clear-all action');
like($recent_index->{'out'}, qr/\bui_list_stacked\b/,
	'index CGI stacks the button under the entry summary');
like($recent_index->{'out'}, qr/\bui_list_icon_box\b/,
	'index CGI lists recent databases with icon tiles');
like($recent_index->{'out'}, qr/\bui_list_link\b[^>]*>sample\.db</,
	'index CGI links the recent database by file name');
like($recent_index->{'out'}, qr/<tt\b[^>]*>[^<]*\/sample\.db<\/tt>/,
	'index CGI shows the recent database path in monospace');
like($recent_index->{'out'}, qr/4 tables/,
	'index CGI shows the table count of the recent database');
like($recent_index->{'out'}, qr/Today, \d\d:\d\d/,
	'index CGI shows when the recent database was opened');
like($recent_index->{'out'}, qr/<a\b(?=[^>]*\bui_list_chevron\b)(?=[^>]*\bhref="database\.cgi\?db=)[^>]*>/,
	'index CGI makes the recent row open the database');
like($recent_index->{'out'}, qr/>Open another file</,
	'index CGI retitles the form once a database is listed');

# Forgetting the entry removes it without touching the database. The list
# stores the resolved path, so take it from the file.
open(my $recent_fh, '<', $recent_file) or die "open $recent_file: $!";
my $recent_line = <$recent_fh>;
close($recent_fh);
chomp($recent_line);
my (undef, undef, $stored_path) = split(/\t/, $recent_line, 3);
my $forgotten = run_cgi('forget_recent.cgi', 'GET', { 'db' => $stored_path });
is($forgotten->{'status'}, 0, 'forget recent CGI exits successfully');
is($forgotten->{'err'}, '', 'forget recent CGI emits no warnings');
like($forgotten->{'out'}, qr/^Location:/mi,
	'forget recent CGI redirects back to the module');
ok(!-e $recent_file, 'forgetting the last entry removes the stored list');
ok(-f $database, 'forgetting an entry leaves the database file alone');
my $after_forget = run_cgi('index.cgi', 'GET', {});
unlike($after_forget->{'out'}, qr/\bui_section_title\b/,
	'index CGI drops the recent list once its last entry is forgotten');

# Check table tabs, editing controls and pagination.
my $table_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'sample' });
is($table_page->{'status'}, 0, 'table CGI exits successfully');
is($table_page->{'err'}, '', 'table CGI emits no warnings');
like($table_page->{'out'}, qr/first/,
	'table CGI displays row data');
like($table_page->{'out'}, qr/Edit/,
	'table CGI offers row editing');
like($table_page->{'out'}, qr/\bui_tabs\b/,
	'table CGI separates structure and data into tabs');
like($table_page->{'out'}, qr/\bui_checked_columns\b/,
	'table CGI renders writable rows with the checked-table helper');
like($table_page->{'out'}, qr/\bselect_all\b/,
	'table CGI provides the standard select-all control');
like($table_page->{'out'}, qr/\bselect_invert\b/,
	'table CGI provides the standard invert-selection control');
like($table_page->{'out'},
	qr/document\.forms\[1\]\.row; ff\.checked = true/,
	'table CGI select-all control targets the delete-row form');
like($table_page->{'out'},
	qr/document\.forms\[1\]\.row; ff\.checked = !ff\.checked/,
	'table CGI invert-selection control targets the delete-row form');
like($table_page->{'out'}, qr/\bui_form_grouped_buttons\b/,
	'table CGI groups its bottom row actions');
like($table_page->{'out'},
	qr/ui_form_grouped_buttons.*?Add Row.*?Delete Selected Rows/s,
	'table CGI keeps separated add and delete actions on the left');
like($table_page->{'out'},
	qr/\bui_stack\b[^>]*\bsqlite_table_footer\b.*?\bui_form_grouped_buttons\b.*?\bsqlite_table_controls\b/s,
	'table CGI spaces the row range below the bottom actions');
like($table_page->{'out'},
	qr/form=['"]sqlite_add_row_form['"].*?action=['"]edit_row\.cgi['"]|action=['"]edit_row\.cgi['"].*?id=['"]sqlite_add_row_form['"]/s,
	'table CGI submits Add Row through its own form');
unlike($table_page->{'out'}, qr/max-width:100%;overflow-x:auto/,
	'table CGI leaves overflow handling to the table widget');
like($table_page->{'out'}, qr/\bui_pager\b/,
	'table CGI renders multi-page results with the pager widget');

# Limit displayed text and check the truncation marker through the language
# loader before restoring the normal long-value test configuration.
write_text(File::Spec->catfile($config_dir, 'sqlite', 'config'),
	"perpage=1\nmax_text=10\nbusy_timeout=100\n".
	"max_query_rows=100\nmax_result_bytes=1048576\nconfirm_delete=1\n");
my $truncated_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'long_sample' });
is($truncated_page->{'status'}, 0,
	'truncated-value table CGI exits successfully');
is($truncated_page->{'err'}, '',
	'truncated-value table CGI emits no warnings');
like($truncated_page->{'out'}, qr/xxxxxxxxxx&hellip;/,
	'truncated values use an encoding-safe ellipsis');
write_text(File::Spec->catfile($config_dir, 'sqlite', 'config'),
	"perpage=1\nmax_text=1000\nbusy_timeout=100\n".
	"max_query_rows=100\nmax_result_bytes=1048576\nconfirm_delete=1\n");

# Check long-text width and disclosure markup.
my $long_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'long_sample' });
is($long_page->{'status'}, 0, 'long-value table CGI exits successfully');
is($long_page->{'err'}, '', 'long-value table CGI emits no warnings');
like($long_page->{'out'}, qr/overflow-wrap:anywhere;word-break:break-word/,
	'long-value cell wraps to fit the available table width');
unlike($long_page->{'out'}, qr/min-width:28em/,
	'long-value cell does not force a wide table');
like($long_page->{'out'}, qr/<details class="inline inlined">/,
	'long-value cell keeps its remaining text in an inline disclosure');

# Editing loads the full value even though table display is shortened.
my $long_raw_key = 'V1:1;';
my $long_key = MIME::Base64::encode_base64($long_raw_key, '');
$long_key =~ tr!+/!-_!;
$long_key =~ s/=+$//;
my $long_edit = run_cgi('edit_row.cgi', 'GET', {
	'db' => $database, 'table' => 'long_sample', 'key' => $long_key });
is($long_edit->{'status'}, 0, 'long-value edit CGI exits successfully');
is($long_edit->{'err'}, '', 'long-value edit CGI emits no warnings');
like($long_edit->{'out'},
	qr/name=['"]value_1['"][^>]*>\Q$long_text\E<\/textarea>/s,
	'row editor loads the full text instead of the display prefix');

# A value larger than the request budget remains browsable because the table
# query returns only its display prefix. Editing refuses it before loading the
# full value into Perl.
my $oversized_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'long_sample', 'start' => 1 });
is($oversized_page->{'status'}, 0,
	'oversized-value table CGI exits successfully');
is($oversized_page->{'err'}, '',
	'oversized-value table CGI emits no warnings');
like($oversized_page->{'out'}, qr/yyyyyyyyyy/,
	'table CGI shows only a bounded prefix of oversized text');
my $oversized_raw_key = 'V1:2;';
my $oversized_key = MIME::Base64::encode_base64($oversized_raw_key, '');
$oversized_key =~ tr!+/!-_!;
$oversized_key =~ s/=+$//;
my $oversized_edit = run_cgi('edit_row.cgi', 'GET', {
	'db' => $database, 'table' => 'long_sample', 'key' => $oversized_key });
like($oversized_edit->{'out'},
	qr/result exceeds the configured 1048576-byte limit/i,
	'row editor rejects an oversized value before loading it');
unlike($oversized_edit->{'out'}, qr/yyyyyyyyyy/,
	'row editor does not return the oversized value');

# An uneven composite key remains editable when its total size is within the
# identity budget. No individual component receives an arbitrary equal share.
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my @uneven_names = map { 'key_'.$_ } 1..10;
$dbh->do('CREATE TABLE uneven_key ('.
	join(', ', map { $_.' TEXT NOT NULL' } @uneven_names).
	', payload TEXT, PRIMARY KEY ('.join(', ', @uneven_names).
	')) WITHOUT ROWID');
my @uneven_values = ('k' x 60000, ('x') x 9, 'visible');
$dbh->do('INSERT INTO uneven_key VALUES ('.
	join(', ', ('?') x scalar(@uneven_values)).')', undef, @uneven_values);
$dbh->disconnect();
my $uneven_key_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'uneven_key' });
is($uneven_key_page->{'status'}, 0,
	'uneven composite-key table CGI exits successfully');
is($uneven_key_page->{'err'}, '',
	'uneven composite-key table CGI emits no warnings');
unlike($uneven_key_page->{'out'}, qr/Key is too large to edit/,
	'composite-key components share one byte budget');
like($uneven_key_page->{'out'},
	qr/edit_row\.cgi\?db=.*?table=uneven%5Fkey/s,
	'a composite key within the total budget remains editable');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my @oversized_key_values = ('z' x 600000, ('x') x 9, 'visible');
$dbh->do('INSERT INTO uneven_key VALUES ('.
	join(', ', ('?') x scalar(@oversized_key_values)).')', undef,
	@oversized_key_values);
$dbh->disconnect();
my $oversized_key_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'uneven_key', 'sort' => 'key_1',
	'start' => 1 });
is($oversized_key_page->{'status'}, 0,
	'oversized composite-key table CGI exits successfully');
is($oversized_key_page->{'err'}, '',
	'oversized composite-key table CGI emits no warnings');
like($oversized_key_page->{'out'}, qr/Key is too large to edit/,
	'an oversized composite key has no edit action');
unlike($oversized_key_page->{'out'}, qr/<input\b[^>]*\bname="row"/,
	'an oversized composite key has no delete checkbox');

# Check that ASCII-only BLOBs stay hidden and binary.
my $blob_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'blob_sample' });
is($blob_page->{'status'}, 0, 'BLOB table CGI exits successfully');
is($blob_page->{'err'}, '', 'BLOB table CGI emits no warnings');
like($blob_page->{'out'}, qr/\[binary value, 10 bytes\]/,
	'BLOB table CGI identifies an ASCII-only BLOB as binary');
unlike($blob_page->{'out'}, qr/ascii blob/,
	'BLOB table CGI does not load the BLOB payload into its output');

my $blob_raw_key = 'V1:1;';
my $blob_key = MIME::Base64::encode_base64($blob_raw_key, '');
$blob_key =~ tr!+/!-_!;
$blob_key =~ s/=+$//;
my $blob_edit = run_cgi('edit_row.cgi', 'GET', {
	'db' => $database, 'table' => 'blob_sample', 'key' => $blob_key });
is($blob_edit->{'status'}, 0, 'BLOB edit CGI exits successfully');
is($blob_edit->{'err'}, '', 'BLOB edit CGI emits no warnings');
like($blob_edit->{'out'}, qr/This binary value \(10 bytes\) cannot be edited here and will remain unchanged/,
	'BLOB edit CGI preserves an ASCII-only BLOB');
like($blob_edit->{'out'}, qr/name=['"]keep_1['"]/,
	'BLOB edit CGI submits the keep-existing marker');
unlike($blob_edit->{'out'}, qr/ascii blob/,
	'BLOB edit CGI does not load the BLOB payload into its output');

# Check the empty-state add-row action.
my $empty_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'empty_sample' });
is($empty_page->{'status'}, 0, 'empty table CGI exits successfully');
is($empty_page->{'err'}, '', 'empty table CGI emits no warnings');
like($empty_page->{'out'}, qr/\bui_empty\b/,
	'empty table CGI renders a styled empty state');
like($empty_page->{'out'}, qr/\bui_svg_icon_database\b/,
	'empty table CGI uses an installed icon');
like($empty_page->{'out'}, qr/>Add Row</,
	'empty table state offers the add-row action');

# Check the table form and its growing number of column rows.
my $table_form = run_cgi('table_form.cgi', 'GET', { 'db' => $database });
is($table_form->{'status'}, 0, 'table form CGI exits successfully');
is($table_form->{'err'}, '', 'table form CGI emits no warnings');
like($table_form->{'out'}, qr/name="name"/, 'table form asks for the table name');
like($table_form->{'out'}, qr/name="name_3"/,
	'table form offers four column rows by default');
unlike($table_form->{'out'}, qr/name="name_4"/,
	'table form offers no fifth row by default');
like($table_form->{'out'}, qr/<option\b(?=[^>]*\bvalue=['"]pkai['"])(?=[^>]*\bselected\b)[^>]*>/,
	'table form proposes an autoincrementing key for the first column');
like($table_form->{'out'}, qr/name=['"]more['"]/,
	'table form offers more column rows');
unlike($table_form->{'out'}, qr/data-sortable=['"]1['"]/,
	'table form leaves its input grid outside DataTables');
my $more = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 4, 'name' => 'notes',
	'name_0' => 'id', 'more' => 1 });
is($more->{'status'}, 0, 'asking for more columns exits successfully');
is($more->{'err'}, '', 'asking for more columns emits no warnings');
like($more->{'out'}, qr/name="name_7"/,
	'asking for more columns shows four more rows');
like($more->{'out'}, qr/name="name"[^>]*value="notes"/,
	'asking for more columns keeps the typed table name');
like($more->{'out'}, qr/name="name_0"[^>]*value="id"/,
	'asking for more columns keeps the typed column names');

# Create a table with a key, a required column and a unique column.
my $created = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 4, 'name' => 'notes',
	'name_0' => 'id', 'type_0' => 'INTEGER', 'null_0' => 0, 'key_0' => 'pkai',
	'name_1' => 'title', 'type_1' => 'TEXT', 'null_1' => 0, 'key_1' => '',
	'default_1' => "it's new",
	'name_2' => 'score', 'type_2' => 'REAL', 'null_2' => 1, 'key_2' => 'unique',
	'default_2' => '1.5',
	'name_3' => '', 'type_3' => 'TEXT', 'null_3' => 1, 'key_3' => '',
	});
is($created->{'status'}, 0, 'create table CGI exits successfully');
is($created->{'err'}, '', 'create table CGI emits no warnings');
like($created->{'out'}, qr/^Location: .*table\.cgi\?db=.*table=notes/mi,
	'create table CGI opens the new table');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($notes_sql) = $dbh->selectrow_array(
	"SELECT sql FROM sqlite_master WHERE name = 'notes'");
like($notes_sql, qr/"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL/,
	'created table has the autoincrementing key');
like($notes_sql, qr/"title" TEXT NOT NULL DEFAULT 'it''s new'/,
	'created table quotes a text default');
like($notes_sql, qr/"score" REAL UNIQUE DEFAULT 1\.5/,
	'created table keeps a numeric default and the unique constraint');
unlike($notes_sql, qr/"" /, 'created table skips the blank column row');
my $composite = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 2, 'name' => 'pairs',
	'name_0' => 'a', 'type_0' => 'TEXT', 'null_0' => 1, 'key_0' => 'pk',
	'name_1' => 'b', 'type_1' => 'INTEGER', 'null_1' => 1, 'key_1' => 'pk',
	});
is($composite->{'err'}, '', 'composite key table emits no warnings');
my ($pairs_sql) = $dbh->selectrow_array(
	"SELECT sql FROM sqlite_master WHERE name = 'pairs'");
like($pairs_sql, qr/"a" TEXT NOT NULL, "b" INTEGER NOT NULL, PRIMARY KEY \("a", "b"\)/,
	'several key columns form a table-level key that never allows NULL');
$dbh->disconnect();

# Check the definition errors the form reports.
my $duplicate = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 1, 'name' => 'notes',
	'name_0' => 'id', 'type_0' => 'INTEGER', 'key_0' => 'pkai' });
like($duplicate->{'out'}, qr/already exists/,
	'create table CGI refuses an existing table name');
my $no_columns = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 1, 'name' => 'nothing' });
like($no_columns->{'out'}, qr/No columns were entered/,
	'create table CGI refuses a table without columns');
my $bad_auto = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 1, 'name' => 'bad',
	'name_0' => 'code', 'type_0' => 'TEXT', 'key_0' => 'pkai' });
like($bad_auto->{'out'}, qr/Autoincrement requires/,
	'create table CGI refuses autoincrement on a text column');
my $reserved = run_cgi('create_table.cgi', 'POST', {
	'db' => $database, 'fields' => 1, 'name' => 'sqlite_mine',
	'name_0' => 'id', 'type_0' => 'INTEGER', 'key_0' => '' });
like($reserved->{'out'}, qr/Invalid table name/,
	'create table CGI refuses the reserved sqlite_ prefix');

# Check the links to the form and the drop buttons on the pages.
my $listing = run_cgi('database.cgi', 'GET', { 'db' => $database });
like($listing->{'out'}, qr/action=['"]table_form\.cgi['"]/,
	'database CGI offers the table form above its object list');
like($listing->{'out'}, qr/value="Create Table"/,
	'database CGI offers the table form as a normal button');
unlike($listing->{'out'}, qr/Create a new table/,
	'database CGI no longer uses a links row for the table form');
my $empty_database = File::Spec->catfile($data_dir, 'empty.db');
DBI->connect('dbi:SQLite:dbname='.$empty_database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 })->disconnect();
my $empty_listing = run_cgi('database.cgi', 'GET', { 'db' => $empty_database });
is($empty_listing->{'err'}, '', 'database CGI opens a zero-byte database');
like($empty_listing->{'out'}, qr/Create the first table/,
	'empty database points writable users at the table form');
like($empty_listing->{'out'}, qr/<a\b(?=[^>]*\bhref="table_form\.cgi\?db=)[^>]*>.*?>Create Table</s,
	'empty database offers the table form as its action');
my $notes_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'notes' });
like($notes_page->{'out'}, qr/action=['"]drop_table\.cgi['"]/,
	'table CGI offers to drop a writable table');
like($notes_page->{'out'}, qr/Drop Table/, 'the drop button names a table');

# Dropping asks first, counts the rows, then removes the table or view.
my $drop_ask = run_cgi('drop_table.cgi', 'POST', {
	'db' => $database, 'table' => 'pairs' });
is($drop_ask->{'err'}, '', 'drop table CGI emits no warnings when asking');
like($drop_ask->{'out'},
	qr/drop the table <tt\b[^>]*>pairs<\/tt>\s*\?.*Row count: 0/s,
	'drop table CGI asks for confirmation with the row count');
like($drop_ask->{'out'}, qr/name=['"]confirm['"]/,
	'drop table CGI confirmation carries the confirm button');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($pairs_before) = $dbh->selectrow_array(
	"SELECT count(*) FROM sqlite_master WHERE name = 'pairs'");
is($pairs_before, 1, 'asking for confirmation drops nothing');
my $dropped = run_cgi('drop_table.cgi', 'POST', {
	'db' => $database, 'table' => 'pairs', 'confirm' => 1 });
is($dropped->{'status'}, 0, 'drop table CGI exits successfully');
is($dropped->{'err'}, '', 'drop table CGI emits no warnings');
like($dropped->{'out'}, qr/^Location: .*database\.cgi/mi,
	'drop table CGI returns to the database');
my ($pairs_after) = $dbh->selectrow_array(
	"SELECT count(*) FROM sqlite_master WHERE name = 'pairs'");
is($pairs_after, 0, 'confirmed drop removes the table');
$dbh->do('CREATE VIEW note_titles AS SELECT title FROM notes');
$dbh->disconnect();
my $view_page = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'note_titles' });
like($view_page->{'out'}, qr/Drop View/, 'the drop button names a view');
my $drop_view_ask = run_cgi('drop_table.cgi', 'POST', {
	'db' => $database, 'table' => 'note_titles' });
like($drop_view_ask->{'out'},
	qr/drop the view <tt\b[^>]*>note_titles<\/tt>\s*\?/,
	'drop table CGI asks about a view without a row count');
my $dropped_view = run_cgi('drop_table.cgi', 'POST', {
	'db' => $database, 'table' => 'note_titles', 'confirm' => 1 });
is($dropped_view->{'err'}, '', 'drop view emits no warnings');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($view_after) = $dbh->selectrow_array(
	"SELECT count(*) FROM sqlite_master WHERE name = 'note_titles'");
is($view_after, 0, 'confirmed drop removes the view');
$dbh->disconnect();

# Add a column through the form and check the definition errors.
my $column_form = run_cgi('column_form.cgi', 'GET', {
	'db' => $database, 'table' => 'notes' });
is($column_form->{'status'}, 0, 'column form CGI exits successfully');
is($column_form->{'err'}, '', 'column form CGI emits no warnings');
like($column_form->{'out'}, qr/name="name"/, 'column form asks for the name');
like($column_form->{'out'}, qr/<select\b[^>]*name="type"/,
	'column form offers the column types');
like($column_form->{'out'}, qr/name="default"/,
	'column form asks for a default');
like($column_form->{'out'}, qr/name="mode"[^>]*value="add"|value="add"[^>]*name="mode"/,
	'column form submits in add mode');
my $added = run_cgi('save_column.cgi', 'POST', {
	'db' => $database, 'table' => 'notes', 'mode' => 'add',
	'name' => 'extra', 'type' => 'TEXT', 'null' => 1, 'default' => 'x' });
is($added->{'status'}, 0, 'save column CGI exits successfully');
is($added->{'err'}, '', 'save column CGI emits no warnings');
like($added->{'out'}, qr/^Location: .*view=structure/mi,
	'save column CGI returns to the structure tab');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
($notes_sql) = $dbh->selectrow_array(
	"SELECT sql FROM sqlite_master WHERE name = 'notes'");
like($notes_sql, qr/"extra" TEXT DEFAULT 'x'/, 'the column was added');
$dbh->disconnect();
my $required = run_cgi('save_column.cgi', 'POST', {
	'db' => $database, 'table' => 'notes', 'mode' => 'add',
	'name' => 'needed', 'type' => 'TEXT', 'null' => 0, 'default' => '' });
like($required->{'out'}, qr/needs a default value/,
	'save column CGI refuses NOT NULL without a default');
my $taken = run_cgi('save_column.cgi', 'POST', {
	'db' => $database, 'table' => 'notes', 'mode' => 'add',
	'name' => 'Title', 'type' => 'TEXT', 'null' => 1, 'default' => '' });
like($taken->{'out'}, qr/already exists/,
	'save column CGI refuses a name already used in any case');
my $view_column = run_cgi('column_form.cgi', 'GET', {
	'db' => $database, 'table' => 'sample_missing' });
like($view_column->{'out'}, qr/does not exist/,
	'column form CGI needs an existing table');

# Rename and drop columns where the library supports it, and explain
# where it does not.
my $structure = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'notes', 'view' => 'structure' });
like($structure->{'out'}, qr/action=['"]column_form\.cgi['"]/,
	'structure tab offers the column form');
like($structure->{'out'}, qr/value="Add Column"/,
	'structure tab offers the column form as a normal button');
like($structure->{'out'}, qr/action=['"]rename_table\.cgi['"]/,
	'structure page offers to rename the table');
like($structure->{'out'}, qr/name="name"[^>]*value="notes"/,
	'the rename row is filled with the current name');
if (sqlite_alter_supported_in_test('rename_column')) {
	like($structure->{'out'}, qr/column_form\.cgi\?[^"]*column=extra"[^>]*>Rename</,
		'structure tab offers to rename a column');
	my $rename_form = run_cgi('column_form.cgi', 'GET', {
		'db' => $database, 'table' => 'notes', 'column' => 'extra' });
	is($rename_form->{'err'}, '', 'rename column form emits no warnings');
	like($rename_form->{'out'}, qr/Current name/, 'rename form shows the old name');
	like($rename_form->{'out'}, qr/name="name"[^>]*value="extra"/,
		'rename form is filled with the old name');
	my $renamed = run_cgi('save_column.cgi', 'POST', {
		'db' => $database, 'table' => 'notes', 'mode' => 'rename',
		'column' => 'extra', 'name' => 'more' });
	is($renamed->{'err'}, '', 'rename column emits no warnings');
	$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
		'RaiseError' => 1, 'PrintError' => 0 });
	my %renamed_columns = map { $_->[1] => 1 }
		@{$dbh->selectall_arrayref('PRAGMA table_info(notes)')};
	ok($renamed_columns{'more'} && !$renamed_columns{'extra'},
		'the column was renamed');
	$dbh->disconnect();
	my $clash = run_cgi('save_column.cgi', 'POST', {
		'db' => $database, 'table' => 'notes', 'mode' => 'rename',
		'column' => 'more', 'name' => 'title' });
	like($clash->{'out'}, qr/already exists/,
		'rename column refuses an existing name');
	}
else {
	# Older libraries must hide the action and reject its form directly.
	unlike($structure->{'out'}, qr/>Rename</,
		'structure tab offers no column rename on an old library');
	my $old_rename = run_cgi('column_form.cgi', 'GET', {
		'db' => $database, 'table' => 'notes', 'column' => 'extra' });
	like($old_rename->{'out'}, qr/too old/,
		'rename column form explains the old library');
	}
my $droppable = sqlite_alter_supported_in_test('rename_column') ? 'more' : 'extra';
if (sqlite_alter_supported_in_test('drop_column')) {
	like($structure->{'out'}, qr/drop_column\.cgi\?[^"]*column=extra"[^>]*>Drop</,
		'structure tab offers to drop a plain column');
	unlike($structure->{'out'}, qr/drop_column\.cgi\?[^"]*column=id"/,
		'structure tab offers no drop for the key column');
	my $drop_ask = run_cgi('drop_column.cgi', 'GET', {
		'db' => $database, 'table' => 'notes', 'column' => $droppable });
	like($drop_ask->{'out'},
		qr/drop the column <tt\b[^>]*>\Q$droppable\E<\/tt>\s+from the table <tt\b[^>]*>notes<\/tt>\s*\?.*Affected rows: 0/s,
		'drop column CGI asks for confirmation with the row count');
	my $drop_done = run_cgi('drop_column.cgi', 'POST', {
		'db' => $database, 'table' => 'notes', 'column' => $droppable,
		'confirm' => 1 });
	is($drop_done->{'err'}, '', 'drop column emits no warnings');
	$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
		'RaiseError' => 1, 'PrintError' => 0 });
	my %left = map { $_->[1] => 1 }
		@{$dbh->selectall_arrayref('PRAGMA table_info(notes)')};
	ok(!$left{$droppable}, 'the column was dropped');
	$dbh->disconnect();
	}
else {
	# Older libraries must hide the action and reject a direct request.
	unlike($structure->{'out'}, qr/drop_column\.cgi/,
		'structure tab offers no column drop on an old library');
	my $old_drop = run_cgi('drop_column.cgi', 'GET', {
		'db' => $database, 'table' => 'notes', 'column' => $droppable });
	like($old_drop->{'out'}, qr/too old/,
		'drop column CGI explains the old library');
	}

# Rename the table there and back, and check the refusals.
my $renamed_table = run_cgi('rename_table.cgi', 'POST', {
	'db' => $database, 'table' => 'notes', 'name' => 'notes_renamed' });
is($renamed_table->{'status'}, 0, 'rename table CGI exits successfully');
is($renamed_table->{'err'}, '', 'rename table CGI emits no warnings');
like($renamed_table->{'out'}, qr/^Location: .*table=notes%5Frenamed.*view=structure/mi,
	'rename table CGI opens the renamed table');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($renamed_count) = $dbh->selectrow_array(
	"SELECT count(*) FROM sqlite_master WHERE name = 'notes_renamed'");
is($renamed_count, 1, 'the table was renamed');
$dbh->disconnect();
my $rename_clash = run_cgi('rename_table.cgi', 'POST', {
	'db' => $database, 'table' => 'notes_renamed', 'name' => 'sample' });
like($rename_clash->{'out'}, qr/already exists/,
	'rename table CGI refuses the name of another table');
my $rename_bad = run_cgi('rename_table.cgi', 'POST', {
	'db' => $database, 'table' => 'notes_renamed', 'name' => 'sqlite_x' });
like($rename_bad->{'out'}, qr/Invalid table name/,
	'rename table CGI refuses a reserved name');
my $rename_back = run_cgi('rename_table.cgi', 'POST', {
	'db' => $database, 'table' => 'notes_renamed', 'name' => 'notes' });
is($rename_back->{'err'}, '', 'renaming back emits no warnings');

# Without write access there is no table form, no drop button, and no
# new-file switch, since a new file could not be given a table.
write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=/\nwrite=0\ncreate=1\nsql=0\n");
my $readonly_form = run_cgi('table_form.cgi', 'GET', { 'db' => $database });
like($readonly_form->{'out'}, qr/do not have write access/,
	'table form CGI refuses a read-only user');
my $readonly_table = run_cgi('table.cgi', 'GET', {
	'db' => $database, 'table' => 'notes' });
unlike($readonly_table->{'out'}, qr/drop_table\.cgi/,
	'table CGI hides the drop button from a read-only user');
unlike($readonly_table->{'out'}, qr/column_form\.cgi|rename_table\.cgi|drop_column\.cgi/,
	'table CGI hides structure changes from a read-only user');
my $readonly_empty = run_cgi('database.cgi', 'GET', { 'db' => $empty_database });
unlike($readonly_empty->{'out'}, qr/table_form\.cgi/,
	'empty database offers no table form to a read-only user');
my $dead_end_index = run_cgi('index.cgi', 'GET', {});
unlike($dead_end_index->{'out'}, qr/Webmin creates the file/,
	'index CGI does not promise a new file when it would be a dead end');
like($dead_end_index->{'out'}, qr/to an existing SQLite file/,
	'index CGI then describes the path field for existing files only');
my $never_database = File::Spec->catfile($data_dir, 'never.db');
my $no_create = run_cgi('open.cgi', 'POST', { 'db' => $never_database });
like($no_create->{'out'}, qr/does not exist/,
	'open CGI does not create a file for a user who could not fill it');
ok(!-e $never_database, 'and leaves no file behind');

# Direct SQL is an independent write capability, while the structured table
# forms remain governed by the normal write ACL.
write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=/\nwrite=0\ncreate=1\nsql=1\n");
my $sql_only_database = File::Spec->catfile($data_dir, 'sql-only.db');
my $sql_only_index = run_cgi('index.cgi', 'GET', {});
like($sql_only_index->{'out'}, qr/Webmin creates the file/,
	'index CGI offers creation when direct SQL can fill the database');
my $sql_only_open = run_cgi('open.cgi', 'POST', {
	'db' => $sql_only_database });
like($sql_only_open->{'out'}, qr/^Location: .*database\.cgi/mi,
	'SQL-only user creates a database file');
my $sql_only_listing = run_cgi('database.cgi', 'GET', {
	'db' => $sql_only_database });
like($sql_only_listing->{'out'}, qr/Use Execute SQL to create the first table/,
	'empty SQL-only database points to the SQL page');
unlike($sql_only_listing->{'out'}, qr/table_form\.cgi/,
	'SQL-only database does not expose the structured table form');
my $sql_only_create = run_cgi('exec.cgi', 'POST', {
	'db' => $sql_only_database,
	'sql' => 'CREATE TABLE sql_only (id INTEGER)',
	});
is($sql_only_create->{'err'}, '', 'SQL-only table creation emits no warnings');
$dbh = DBI->connect('dbi:SQLite:dbname='.$sql_only_database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($sql_only_table) = $dbh->selectrow_array(
	"SELECT count(*) FROM sqlite_master WHERE name = 'sql_only'");
is($sql_only_table, 1, 'SQL permission can change a writable database');
$dbh->disconnect();

write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=/\nwrite=1\ncreate=1\nsql=0\n");
my $form_only_index = run_cgi('index.cgi', 'GET', {});
like($form_only_index->{'out'}, qr/Webmin creates the file/,
	'index CGI offers a new file when the table form can fill it');
write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=/\nwrite=1\ncreate=1\nsql=1\n");

# Insert a row and check the fixture database.
my $insert = run_cgi('save_row.cgi', 'POST', {
	'db' => $database,
	'table' => 'sample',
	'new' => 1,
	'default_0' => 1,
	'value_1' => 'third',
	});
is($insert->{'status'}, 0, 'row insert CGI exits successfully');
is($insert->{'err'}, '', 'row insert CGI emits no warnings');

$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($third_count) = $dbh->selectrow_array(
	"SELECT count(*) FROM sample WHERE name = 'third'");
is($third_count, 1, 'row insert CGI writes the new row');
$dbh->disconnect();

# Execute SQL through the authorizer-protected CGI.
my $sql = run_cgi('exec.cgi', 'POST', {
	'db' => $database,
	'sql' => 'SELECT name FROM sample ORDER BY id',
	});
is($sql->{'status'}, 0, 'SQL CGI exits successfully');
is($sql->{'err'}, '', 'SQL CGI emits no warnings');
like($sql->{'out'}, qr/third/,
	'SQL CGI displays query results');
like($sql->{'out'}, qr/data-sortable=['"]1['"]/,
	'SQL CGI explicitly makes result rows sortable');
# Report byte truncation separately from row truncation.
my $large_sql = run_cgi('exec.cgi', 'POST', {
	'db' => $database,
	'sql' => 'SELECT zeroblob(1048577)',
	});
like($large_sql->{'out'},
	qr/Additional result data was omitted after reaching the 1048576-byte limit/i,
	'SQL CGI identifies byte truncation instead of a row limit');
unlike($large_sql->{'out'}, qr/Only the first 100 rows are shown/,
	'byte truncation does not report the configured row limit');
# Keep the result ceiling from restricting a write-only statement.
my $large_write = run_cgi('exec.cgi', 'POST', {
	'db' => $database,
	'sql' => 'INSERT INTO blob_sample (data) VALUES (zeroblob(1048577))',
	});
is($large_write->{'err'}, '',
	'large direct SQL write emits no warnings');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($large_blob) = $dbh->selectrow_array(
	'SELECT max(length(data)) FROM blob_sample');
$dbh->disconnect();
is($large_blob, 1048577,
	'result-data limit does not reject a valid direct SQL write');
my $two_statements = run_cgi('exec.cgi', 'POST', {
	'db' => $database,
	'sql' => "SELECT name FROM sample; DELETE FROM sample",
	});
like($two_statements->{'out'}, qr/Only one SQL statement can be run/,
	'SQL CGI refuses a second statement');
$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($kept_rows) = $dbh->selectrow_array('SELECT count(*) FROM sample');
$dbh->disconnect();
ok($kept_rows > 0, 'the refused second statement did not run');

# Delete one row through its opaque identity.
my $raw_key = 'V1:1;';
my $key = MIME::Base64::encode_base64($raw_key, '');
$key =~ tr!+/!-_!;
$key =~ s/=+$//;
my $delete = run_cgi('delete_rows.cgi', 'POST', {
	'db' => $database,
	'table' => 'sample',
	'row' => $key,
	'confirm' => 1,
	});
is($delete->{'status'}, 0, 'row delete CGI exits successfully');
is($delete->{'err'}, '', 'row delete CGI emits no warnings');

$dbh = DBI->connect('dbi:SQLite:dbname='.$database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
my ($first_count) = $dbh->selectrow_array(
	"SELECT count(*) FROM sample WHERE name = 'first'");
is($first_count, 0, 'row delete CGI removes the selected row');
$dbh->disconnect();

# Check that denied paths reveal no contents or file metadata.
write_text(File::Spec->catfile($config_dir, 'sqlite', 'admin.acl'),
	"paths=$data_dir\nwrite=1\ncreate=1\nsql=1\n");
my $outside_database = File::Spec->catfile($temp, 'outside.db');
$dbh = DBI->connect('dbi:SQLite:dbname='.$outside_database, '', '', {
	'RaiseError' => 1, 'PrintError' => 0 });
$dbh->do('CREATE TABLE private_data (value TEXT)');
$dbh->disconnect();
my $outside_page = run_cgi('database.cgi', 'GET', {
	'db' => $outside_database });
like($outside_page->{'out'}, qr/outside the allowed directories/,
	'database CGI rejects a file outside its ACL');
like($outside_page->{'out'},
	qr/Allowed directories:.*\Q$data_dir\E/s,
	'denied path error lists the database roots allowed by the ACL');
unlike($outside_page->{'out'}, qr/private_data/,
	'rejected database contents are not displayed');

my $outside_missing = run_cgi('database.cgi', 'GET', {
	'db' => File::Spec->catfile($temp, 'missing.db') });
like($outside_missing->{'out'}, qr/outside the allowed directories/,
	'missing path outside the ACL returns the same access error');
unlike($outside_missing->{'out'}, qr/does not exist/,
	'missing path outside the ACL does not reveal file metadata');

# Check canonical paths when the platform supports symbolic links.
SKIP: {
	my $linked_database = File::Spec->catfile($data_dir, 'linked.db');
	# Skip only this platform-specific assertion when symlink creation fails.
	skip('symbolic links are unavailable', 1)
		if (!symlink($outside_database, $linked_database));
	my $linked_page = run_cgi('database.cgi', 'GET', {
		'db' => $linked_database });
	like($linked_page->{'out'}, qr/outside the allowed directories/,
		'database symlink cannot escape the allowed directory');
	}

# Drive the access-control editor the way the ACL module does, through a
# helper that loads acl_security.pl as a foreign module and prints the form,
# then saves the mode named by ACL_TEST_MODE.
my $acl_helper = File::Spec->catfile($temp, 'acl_helper.pl');
write_text($acl_helper, <<'HELPER');
use strict;
use warnings;
no warnings 'once';
require 'web-lib.pl';
require 'ui-lib.pl';
&init_config();
&foreign_require('sqlite', 'acl_security.pl');
print "Content-type: text/html\n\n";
my %o = ( 'paths' => '$HOME', 'write' => 1, 'create' => 1, 'sql' => 0 );
# The ACL module wraps every module form in a four-column table.
print &ui_table_start('Access', 'width=100%', 4);
&foreign_call('sqlite', 'acl_security_form', \%o);
print &ui_table_end();
my %modes = (
	'root' => { 'user_mode' => 0, 'acl_user' => '' },
	'same' => { 'user_mode' => 1, 'acl_user' => '' },
	'named' => { 'user_mode' => 2, 'acl_user' => $ENV{'ACL_TEST_USER'} },
	'bad' => { 'user_mode' => 2, 'acl_user' => 'sqlite-no-such-user' },
	);
my %in = ( 'paths' => "\$HOME\n$ENV{'ACL_TEST_DIR'}\n", 'write' => 1,
	   'create' => 0, 'sql' => 0, %{ $modes{$ENV{'ACL_TEST_MODE'}} } );
&foreign_call('sqlite', 'acl_security_save', \%o, \%in);
print "SAVED paths=[$o{'paths'}] write=$o{'write'} create=$o{'create'} ",
      "work_as_root=$o{'work_as_root'} work_as_user=[$o{'work_as_user'}]\n";
HELPER
my @acl_test_user = getpwuid($<);
my %acl_env = ( 'ACL_TEST_DIR' => $data_dir,
		'ACL_TEST_USER' => $acl_test_user[0] || 'root' );
my $acl_form = run_cgi($acl_helper, 'GET', {}, undef,
	{ 'script_name' => '/acl/edit_acl.cgi',
	  'env' => { %acl_env, 'ACL_TEST_MODE' => 'named' } });
is($acl_form->{'status'}, 0, 'ACL editor helper exits successfully');
is($acl_form->{'err'}, '', 'ACL editor helper emits no warnings');
like($acl_form->{'out'}, qr/<textarea\b[^>]*\bname="paths"[^>]*>\$HOME</,
	'ACL editor shows the $HOME token rather than an expanded home');
like($acl_form->{'out'}, qr/Unix user for database access/,
	'ACL editor offers the Unix user choice');
like($acl_form->{'out'},
	qr/<input\b(?=[^>]*\bname="user_mode")(?=[^>]*\bvalue="1")(?=[^>]*\bchecked)[^>]*>/,
	'ACL editor derives the same-user mode for an older home-only ACL');
like($acl_form->{'out'}, qr/\bname="acl_user"/,
	'ACL editor has a field for a specific Unix user');
# Real directories are stored canonically, so compare with links resolved.
my $resolved_data_dir = abs_path($data_dir);
like($acl_form->{'out'},
	qr/SAVED paths=\[\$HOME\t\Q$resolved_data_dir\E\] write=1 create=0 work_as_root=0 work_as_user=\[\Q$acl_env{'ACL_TEST_USER'}\E\]/,
	'ACL editor keeps $HOME, resolves real directories and stores a named user');
my $acl_root = run_cgi($acl_helper, 'GET', {}, undef,
	{ 'script_name' => '/acl/edit_acl.cgi',
	  'env' => { %acl_env, 'ACL_TEST_MODE' => 'root' } });
like($acl_root->{'out'}, qr/work_as_root=1 work_as_user=\[\]/,
	'ACL editor stores the root mode without a user name');
my $acl_same = run_cgi($acl_helper, 'GET', {}, undef,
	{ 'script_name' => '/acl/edit_acl.cgi',
	  'env' => { %acl_env, 'ACL_TEST_MODE' => 'same' } });
like($acl_same->{'out'}, qr/work_as_root=0 work_as_user=\[\]/,
	'ACL editor stores the same-user mode without a user name');
my $acl_bad = run_cgi($acl_helper, 'GET', {}, undef,
	{ 'script_name' => '/acl/edit_acl.cgi',
	  'env' => { %acl_env, 'ACL_TEST_MODE' => 'bad' } });
isnt($acl_bad->{'status'}, 0, 'ACL editor rejects an unknown Unix user');
like($acl_bad->{'out'}, qr/Enter a valid Unix user/,
	'ACL editor names the unknown Unix user problem');
unlike($acl_bad->{'out'}, qr/SAVED/,
	'ACL editor saves nothing for an unknown Unix user');

done_testing();
