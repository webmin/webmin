# sqlite-lib.pl
# Shared functions for browsing and editing SQLite databases.

BEGIN { push(@INC, ".."); }
use WebminCore;
use strict;
use warnings;
use Encode qw(decode FB_CROAK);
use MIME::Base64 ();
use POSIX ();

our (%config, %access, %text, %module_info, $module_name,
	$module_config_directory, $remote_user);
our ($sqlite_driver_loaded, $sqlite_driver_error, $sqlite_unix_home);

# Load Webmin configuration unless a test provides isolated globals, then
# drop root for the Unix user the ACL names before any file is touched.
if (!$ENV{'SQLITE_TESTING'}) {
	&init_config();
	%access = &get_module_acl();
	&sqlite_switch_user();
	}

# sub sqlite_work_as_user([&acl])
# Returns the Unix user that file and database work should run as, or
# undef to stay root: a named user from the ACL, the Webmin user's own
# account when the ACL says so, or for an ACL written before the setting
# existed, that account when the ACL allows only the user's home.
sub sqlite_work_as_user
{
my ($acl) = @_;
$acl ||= \%access;
# Honor explicit root and named-user modes before checking legacy ACLs.
return undef if ($acl->{'work_as_root'});
return $acl->{'work_as_user'} if ($acl->{'work_as_user'});
# An older ACL has no setting; only a home-only one implies the user.
if (!defined($acl->{'work_as_root'})) {
	my @paths = grep { length($_) }
			 split(/\t+|\r?\n/, defined($acl->{'paths'}) ?
						$acl->{'paths'} : '');
	return undef if (!@paths || grep { $_ ne '$HOME' } @paths);
	}
# The remaining explicit or inferred mode uses the matching Webmin user.
return $remote_user;
}

# sub sqlite_switch_user()
# Switches the process to the Unix user from sqlite_work_as_user, so that
# the kernel enforces every file permission on database files and nothing
# in a user's directory is done as root. Does nothing when the module is
# to stay root, already runs without root, or was loaded by another
# module's CGI, such as the ACL editor, which must keep its own identity.
sub sqlite_switch_user
{
return if ($< != 0);
return if (($ENV{'SCRIPT_NAME'} || '') !~ m!^/\Q$module_name\E/!);
my $user = &sqlite_work_as_user();
return if (!defined($user) || $user eq '');
my @uinfo = getpwnam($user);
@uinfo || &error(&text('error_nouser', &html_escape($user)));
&switch_to_unix_user(\@uinfo);
# Tell the rest of Webmin, and programs run later, who we are now.
$ENV{'USER'} = $ENV{'LOGNAME'} = $uinfo[0];
$ENV{'HOME'} = $uinfo[7];
@WebminCore::remote_user_info = @uinfo;
$sqlite_unix_home = $uinfo[7];
}

# sub sqlite_acl_paths(value)
# Returns allowed database directories, expanding $HOME for the Unix user.
# Keep explicit ACL paths fixed after saving them. Resolve $HOME so
# administrator-managed links such as /home -> /data continue to work.
sub sqlite_acl_paths
{
my ($value) = @_;
# An unset ACL must grant no filesystem access.
return () if (!defined($value) || $value eq '');
my @paths = grep { length($_) } split(/\t+|\r?\n/, $value);
# $HOME belongs to the Unix user the module works as, or otherwise to the
# Unix account named like the Webmin user.
my $owner = &sqlite_work_as_user() || $remote_user;
my @user = $owner ? getpwnam($owner) : ( );
my @resolved;
foreach my $path (@paths) {
	# $HOME is valid only when the ACL identifies a matching Unix user.
	if ($path eq '$HOME') {
		$path = $user[7] ?
			&simplify_path(&resolve_links($user[7])) : undef;
		}
	else {
		# The ACL editor stores canonical paths. Normalize lexical components
		# without following a link that may have been replaced later.
		$path = &simplify_path($path);
		}
	# Discard unresolved or non-absolute ACL entries.
	push(@resolved, $path) if ($path && $path =~ m!^/!);
	}
return @resolved;
}

# sub sqlite_load_driver()
# Loads DBI and DBD::SQLite. Returns an error string on failure.
sub sqlite_load_driver
{
# Reuse the first result for the rest of the request.
return undef if ($sqlite_driver_loaded);
return $sqlite_driver_error if (defined($sqlite_driver_error));

# Load both modules and initialize the SQLite driver immediately.
eval {
	require DBI;
	require DBD::SQLite;
	DBI->install_driver('SQLite');
	};
# Save the loader error for the installation prompt and later calls.
if ($@) {
	$sqlite_driver_error = $@;
	$sqlite_driver_error =~ s/\s+$//;
	return $sqlite_driver_error;
	}
$sqlite_driver_loaded = 1;
return undef;
}

# sub sqlite_versions()
# Returns the SQLite library version and the DBD::SQLite version once the
# driver is loaded, or an empty list.
sub sqlite_versions
{
return () if (!$sqlite_driver_loaded);
no warnings 'once';
return ($DBD::SQLite::sqlite_version, $DBD::SQLite::VERSION);
}

# sub sqlite_path_under(path, directory)
# Returns true when a canonical candidate path is the saved ACL directory or
# one of its descendants. Callers resolve candidate links but keep saved ACL
# roots unchanged.
sub sqlite_path_under
{
my ($path, $dir) = @_;
$path = &simplify_path($path);
$dir = &simplify_path($dir);
# Reject paths that cannot be normalized.
return 0 if (!defined($path) || !defined($dir));
# A root ACL includes every absolute path.
return 1 if ($dir eq '/');
# Accept the configured directory itself as well as its descendants.
return 1 if ($path eq $dir);
$dir =~ s!/+$!!;
return index($path, $dir.'/') == 0;
}

# sub sqlite_acl_unrestricted()
# Returns true when the ACL includes the filesystem root.
sub sqlite_acl_unrestricted
{
foreach my $dir (&sqlite_acl_paths($access{'paths'})) {
	# Only the exact root path grants unrestricted filesystem access.
	return 1 if ($dir eq '/');
	}
return 0;
}

# sub sqlite_secure_open_available([sqlite-version])
# Returns true when the active ACL can be enforced while opening a validated
# database path. sqlite-version overrides the loaded version for tests. A
# restricted ACL requires SQLite 3.39 or later to reject links in every path
# component.
sub sqlite_secure_open_available
{
my ($version) = @_;
# An unrestricted ACL has no narrower directory boundary to escape.
return 1 if (&sqlite_acl_unrestricted());
return &sqlite_supports('nofollow', $version);
}

# sub sqlite_path_allowed(path)
# Returns true when a path lies inside one of the ACL's allowed directories.
sub sqlite_path_allowed
{
my ($path) = @_;
foreach my $dir (&sqlite_acl_paths($access{'paths'})) {
	# Stop at the first ACL root that contains the path.
	return 1 if (&sqlite_path_under($path, $dir));
	}
return 0;
}

# sub sqlite_database_path(path, [create])
# Resolves and validates a database path against the module ACL. Set create
# to permit a missing final file when its parent directory is writable.
sub sqlite_database_path
{
my ($path, $create) = @_;
# Normalize an omitted form value before validating it.
$path = '' if (!defined($path));
$path =~ s/^\s+|\s+$//g;
# Require an absolute, single-line path before any filesystem access.
if ($path !~ m!^/! || $path =~ /[\0\r\n]/) {
	&error(&text('error_path', &html_escape($path)));
	}

my $simple = &simplify_path($path);
defined($simple) || &error(&text('error_path', &html_escape($path)));
# Resolve links before applying directory boundaries, file checks or errors.
my $resolved = &simplify_path(&resolve_links($simple));
defined($resolved) || &error(&text('error_path', &html_escape($path)));

# Apply the ACL before any file metadata error, so paths outside the
# allowed directories cannot be probed for existence or type. A rejection
# names the ACL roots, escaped so that ACL text cannot become HTML.
if (!&sqlite_path_allowed($resolved)) {
	my @allowed_paths = &sqlite_acl_paths($access{'paths'});
	my $allowed_text = @allowed_paths ?
		join(', ', map { &ui_tag('tt', &html_escape($_)) }
			@allowed_paths) :
		&html_escape($text{'error_noallowed'});
	&error(&text('error_notallowed', &html_escape($resolved),
		$allowed_text));
	}

# Validate an existing file, or validate the parent before creating a new one.
if (-e $resolved) {
	# Existing databases must be readable regular files.
	-f $resolved || &error(&text('error_notfile', &html_escape($resolved)));
	-r $resolved || &error(&text('error_noread', &html_escape($resolved)));
	}
else {
	# New files require create permission and a writable parent directory.
	$create || &error(&text('error_missing', &html_escape($resolved)));
	$access{'create'} || &error($text{'error_nocreate'});
	my ($parent, $name) = $resolved =~ m!^(.*)/([^/]+)$!;
	# A path directly below the filesystem root captures an empty parent.
	$parent = '/' if ($parent eq '');
	$name ne '' || &error(&text('error_path', &html_escape($path)));
	-d $parent || &error(&text('error_noparent', &html_escape($parent)));
	-w $parent || &error(&text('error_nowrite', &html_escape($parent)));
	}
return $resolved;
}

# sub sqlite_can_create()
# Returns true when this user may create database files: the ACL allows
# it and the user can give the new file a table, through the table form
# or through SQL. Otherwise a new file would be a dead end.
sub sqlite_can_create
{
return $access{'create'} && ($access{'write'} || $access{'sql'}) ? 1 : 0;
}

# sub sqlite_can_write(path)
# Returns true when ACLs and filesystem permissions allow database changes.
sub sqlite_can_write
{
my ($path) = @_;
# The module ACL takes precedence over filesystem permissions.
return 0 if (!$access{'write'});
return &sqlite_file_writable($path);
}

# sub sqlite_can_sql_write(path)
# Returns true when direct SQL may change a database and the filesystem
# permits the change. Structured row and schema controls use sqlite_can_write
# instead, so their separate ACL remains effective.
sub sqlite_can_sql_write
{
my ($path) = @_;
return 0 if (!$access{'sql'});
return &sqlite_file_writable($path);
}

# sub sqlite_file_writable(path)
# Returns true when SQLite can replace the database and create its journal
# files. Callers must apply the relevant module capability first.
sub sqlite_file_writable
{
my ($path) = @_;
my ($parent) = $path =~ m!^(.*)/[^/]+$!;
# Files directly below the filesystem root have root as their parent.
$parent = '/' if (!defined($parent) || $parent eq '');
return (-w $path && -w $parent) ? 1 : 0;
}

# sub sqlite_filename_uri(path)
# Encodes an absolute filename as an SQLite file URI. The URI form keeps
# semicolons and equals signs in a Unix filename from becoming DBD connection
# parameters such as a second dbname.
sub sqlite_filename_uri
{
my ($path) = @_;
my $bytes = $path;
# URI percent escapes describe filename bytes, not Perl characters.
utf8::encode($bytes) if (utf8::is_utf8($bytes));
$bytes =~ s!([^A-Za-z0-9._~/-])!sprintf('%%%02X', ord($1))!ge;
return 'file:'.$bytes;
}

# sub sqlite_connect(path, [write], [create], [sql-write])
# Opens a database using SQLite's read-only or read-write connection mode.
# Set write for a read-write handle, create to allow a missing file, and
# sql-write when the SQL ACL authorizes the write instead of the structured
# editing ACL.
sub sqlite_connect
{
my ($path, $write, $create, $sql_write) = @_;
$path = &sqlite_database_path($path, $create);
# An existing path always uses normal open semantics, even if create was set.
$create = 0 if (-e $path);
my $driver_error = &sqlite_load_driver();
$driver_error && &error(&text('error_driver', &html_escape($driver_error)));
# Protect every restricted path ACL against an ancestor symlink race.
&sqlite_secure_open_available() || &error($text{'error_secureopen'});
# Refuse writes denied by the applicable ACL or filesystem.
if ($write && !$create && !($sql_write ? &sqlite_can_sql_write($path) :
					 &sqlite_can_write($path))) {
	&error($text{'error_readonly'});
	}

# SQLite open flags: 1 is read-only, 2 is read-write, and 6 also permits
# creation. DBD::SQLite adds the URI flag when it parses the uri= DSN.
my $flags = $create ? 6 : $write ? 2 : 1;
# The validated path holds no symbolic link, so refuse one planted there
# between validation and the open, where SQLite can check for it.
$flags |= 0x01000000 if (&sqlite_supports('nofollow'));
my %attributes = (
	'RaiseError' => 1,
	'PrintError' => 0,
	'AutoCommit' => 1,
	'sqlite_unicode' => 1,
	'sqlite_open_flags' => $flags,
	'sqlite_allow_multiple_statements' => 0,
	);
# Defensive mode blocks SQL features that can directly corrupt the database.
$attributes{'sqlite_defensive'} = 1
	if (eval { DBD::SQLite->VERSION(1.64); 1 });
my $dbh = eval {
	DBI->connect('dbi:SQLite:uri='.&sqlite_filename_uri($path), '', '',
		\%attributes);
	};
# Report driver exceptions through Webmin's escaped error page.
if (!$dbh) {
	my $message = $@ || DBI->errstr || $text{'error_unknown'};
	&error(&text('error_connect', &html_escape($path),
		&html_escape($message)));
	}
my $timeout = int($config{'busy_timeout'} || 5000);
# A negative timeout means fail immediately.
$timeout = 0 if ($timeout < 0);
# Cap lock waits at ten minutes.
$timeout = 600000 if ($timeout > 600000);
$dbh->do('PRAGMA busy_timeout = '.$timeout);
# Enforce foreign keys, and refuse functions and virtual tables that a
# schema from an untrusted file could otherwise run.
$dbh->do('PRAGMA foreign_keys = ON');
$dbh->do('PRAGMA trusted_schema = OFF');
# Enforce query-only behavior inside SQLite as well as through open flags.
$dbh->do('PRAGMA query_only = ON') if (!$write && !$create);
# Read the schema now so invalid database files fail before use.
eval { $dbh->selectrow_array('PRAGMA schema_version'); };
# Close an unusable handle before reporting the error.
if ($@) {
	my $message = $@;
	$dbh->disconnect();
	&error(&text('error_connect', &html_escape($path),
		&html_escape($message)));
	}
return $dbh;
}

# sub sqlite_adopt_ownership(path)
# Gives SQLite journal files the same owner as the database. When Webmin
# writes as root, a root-owned -wal or -shm file can lock out the application
# that owns the database.
sub sqlite_adopt_ownership
{
my ($path) = @_;
# Only root can hand files to another user, and root's own stay as is.
return if ($< != 0);
my @st = stat($path);
return if (!@st || $st[4] == 0);
foreach my $suffix ('-journal', '-wal', '-shm') {
	# lchown does not follow a link planted after the file-type check.
	&sqlite_safe_chown($path.$suffix, $st[4], $st[5]);
	}
}

# sub sqlite_safe_chown(path, uid, gid)
# Gives a regular file to one user and group without following a symbolic
# link. Returns true on success and false when the target cannot be changed
# safely.
sub sqlite_safe_chown
{
my ($path, $uid, $gid) = @_;
my @st = lstat($path);
# Refuse links and every other non-regular file before changing ownership.
return 0 if (!@st || !-f _);
# A replacement link is still safe because lchown changes the link itself.
my $rv = eval { POSIX::lchown($uid, $gid, $path) };
return defined($rv) && $rv == 0 ? 1 : 0;
}

# sub sqlite_quote_identifier(name)
# Quotes an SQLite table or column identifier.
sub sqlite_quote_identifier
{
my ($name) = @_;
$name =~ s/"/""/g;
return '"'.$name.'"';
}

# sub sqlite_objects(dbh)
# Returns user-created tables and views from an open database.
sub sqlite_objects
{
my ($dbh) = @_;
return $dbh->selectall_arrayref(
	"SELECT name, type, sql FROM sqlite_master " .
	"WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' " .
	"ORDER BY type, lower(name)", { 'Slice' => {} });
}

# sub sqlite_object(dbh, name)
# Returns a named table or view, or undef when it does not exist.
sub sqlite_object
{
my ($dbh, $name) = @_;
return $dbh->selectrow_hashref(
	"SELECT name, type, sql FROM sqlite_master " .
	"WHERE type IN ('table', 'view') AND name = ? " .
	"AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\'", undef, $name);
}

# sub sqlite_table_columns(dbh, table)
# Returns visible and generated columns for a table or view.
sub sqlite_table_columns
{
my ($dbh, $table) = @_;
my $quoted = &sqlite_quote_identifier($table);
# Prefer table_xinfo because it includes generated columns.
my $rows = eval {
	$dbh->selectall_arrayref("PRAGMA table_xinfo($quoted)",
		{ 'Slice' => {} });
	};
# Fall back for older SQLite versions that lack table_xinfo.
$rows = $dbh->selectall_arrayref("PRAGMA table_info($quoted)",
	{ 'Slice' => {} }) if (!$rows);
# table_info results do not include the hidden-column flag.
foreach my $col (@$rows) {
	# Treat columns without this flag as visible.
	$col->{'hidden'} = 0 if (!defined($col->{'hidden'}));
	}
return [ grep { $_->{'hidden'} != 1 } @$rows ];
}

# sub sqlite_column_selects(&columns, [&blob-columns-to-keep])
# Returns value, storage class and length expressions. BLOB bodies are omitted
# unless requested.
sub sqlite_column_selects
{
my ($columns, $keep_blobs) = @_;
$keep_blobs ||= { };
my (@values, @types, @lengths);
foreach my $column (@$columns) {
	# Fetch BLOB bytes only when they identify the row.
	my $name = $column->{'name'};
	my $quoted = &sqlite_quote_identifier($name);
	push(@values, $keep_blobs->{$name} ? $quoted :
		"CASE WHEN typeof($quoted) = 'blob' THEN NULL ELSE $quoted END");
	push(@types, "typeof($quoted)");
	push(@lengths, "length($quoted)");
	}
return (\@values, \@types, \@lengths);
}

# sub sqlite_identity(dbh, object, columns)
# Chooses a stable row identity for editing a table.
sub sqlite_identity
{
my ($dbh, $object, $columns) = @_;
# Views have no identity that is safe for row updates.
return undef if ($object->{'type'} ne 'table');
my %names = map { lc($_->{'name'}) => 1 } @$columns;
# Ordinary tables can use an unshadowed SQLite rowid alias.
if (($object->{'sql'} || '') !~ /\bWITHOUT\s+ROWID\b/i) {
	foreach my $rowid ('rowid', '_rowid_', 'oid') {
		# Use the first alias that is not shadowed by a declared column.
		return { 'rowid' => $rowid, 'columns' => [ ] }
			if (!$names{$rowid});
		}
	}
# Other tables need a declared primary key.
my @pk = sort { $a->{'pk'} <=> $b->{'pk'} }
	grep { $_->{'pk'} } @$columns;
return @pk ? { 'columns' => [ map { $_->{'name'} } @pk ] } : undef;
}

# sub sqlite_encode_key(values...)
# Encodes one or more row identity values into an opaque URL-safe token.
sub sqlite_encode_key
{
my (@values) = @_;
my $raw = '';
foreach my $value (@values) {
	# Preserve NULL separately from empty text.
	if (!defined($value)) {
		$raw .= 'N;';
		}
	else {
		# Record the byte length and whether to restore the Unicode
		# flag.
		my $bytes = $value;
		my $tag = utf8::is_utf8($bytes) ? 'U' : 'V';
		# Encode Unicode before recording a byte length in the token.
		utf8::encode($bytes) if ($tag eq 'U');
		$raw .= $tag.length($bytes).':'.$bytes.';';
		}
	}
# Convert the framed values to unpadded URL-safe Base64.
my $encoded = MIME::Base64::encode_base64($raw, '');
$encoded =~ tr!+/!-_!;
$encoded =~ s/=+$//;
return $encoded;
}

# sub sqlite_decode_key(token, count)
# Decodes and validates a row identity token.
sub sqlite_decode_key
{
my ($token, $count) = @_;
# Normalize an omitted token so it follows the normal validation path.
$token = '' if (!defined($token));
$token =~ tr!-_!+/!;
$token .= '=' x ((4 - length($token) % 4) % 4);
my $raw = MIME::Base64::decode_base64($token);
my @values;
while (length($raw)) {
	# Restore an encoded NULL field.
	if ($raw =~ s/^N;//) {
		push(@values, undef);
		}
	elsif ($raw =~ s/^([VU])([0-9]+)://) {
		# Restore one length-prefixed byte or Unicode value.
		my $tag = $1;
		my $length = $2;
		$length <= length($raw) || &error($text{'error_key'});
		my $value = substr($raw, 0, $length, '');
		$raw =~ s/^;// || &error($text{'error_key'});
		# Restore Perl's Unicode flag only for values encoded with the
		# U tag.
		utf8::decode($value) if ($tag eq 'U');
		push(@values, $value);
		}
	else {
		# Reject malformed tags, lengths and separators.
		&error($text{'error_key'});
		}
	}
@values == $count || &error($text{'error_key'});
return @values;
}

# sub sqlite_identity_where(&identity, &values)
# Builds a parameterized WHERE clause for a row identity.
sub sqlite_identity_where
{
my ($identity, $values) = @_;
# A rowid identity needs one direct equality comparison.
if ($identity->{'rowid'}) {
	return ($identity->{'rowid'}.' = ?', @$values);
	}
# Match every component of a declared composite primary key.
my @parts = map { &sqlite_quote_identifier($_).' IS ?' }
	@{$identity->{'columns'}};
return (join(' AND ', @parts), @$values);
}

# sub sqlite_value_is_binary(value)
# Returns true when a database value cannot be safely shown as UTF-8 text.
sub sqlite_value_is_binary
{
my ($value) = @_;
# NULL has no bytes to classify.
return 0 if (!defined($value));
# Control bytes are unsafe even within valid UTF-8.
return 1 if ($value =~ /[\x00-\x08\x0b\x0c\x0e-\x1f]/);
# Perl has already validated values carrying its Unicode flag.
return 0 if (utf8::is_utf8($value));
return !eval { decode('UTF-8', $value, FB_CROAK); 1 };
}

# sub sqlite_display_value(value, [storage-type], [storage-length])
# Formats a database value for safe display in an HTML table.
sub sqlite_display_value
{
my ($value, $storage_type, $storage_length) = @_;
# Use SQLite's storage class so ASCII-only BLOBs remain binary.
if (defined($storage_type) && $storage_type eq 'blob') {
	my $length = defined($storage_length) ? $storage_length :
		length(defined($value) ? $value : '');
	return &text('value_blob', $length);
	}
# Render SQL NULL with a distinct visual marker.
return &ui_tag('i', $text{'value_null'}) if (!defined($value));
# Hide binary values when no SQLite storage class was supplied.
return &text('value_blob', length($value)) if (&sqlite_value_is_binary($value));
my $shown = $value;
my $max = int($config{'max_text'} || 0);
my $truncated;
# Apply the display limit before building the details disclosure.
if ($max > 0 && length($shown) > $max) {
	$shown = substr($shown, 0, $max);
	$truncated = 1;
	}
my $preview_length = 128;
# Short values need no expandable details control.
if (length($shown) <= $preview_length) {
	return &ui_tag('span', &html_escape($shown).
		($truncated ? $text{'value_more'} : ''), {
			'style' => 'white-space:normal;overflow-wrap:anywhere;'.
				'word-break:break-word;',
			});
	}

# Longer values show a preview and keep the rest in a disclosure whose
# summary counts the hidden characters.
my $preview = substr($shown, 0, $preview_length);
my $remainder = substr($shown, $preview_length);
my $remaining = length($value) - $preview_length;
my $summary = $truncated ?
	&text('value_more_chars_truncated', length($remainder), $remaining) :
	&text('value_more_chars', $remaining);
my $content = &html_escape($remainder).
	($truncated ? $text{'value_more'} : '');
return &ui_tag('span', &html_escape($preview).' '.&ui_details({
		'html' => 1,
		'title' => &html_escape($summary),
		'content' => &ui_tag('span', $content, {
			'style' => 'white-space:normal;overflow-wrap:anywhere;',
			}),
		'class' => 'inline inlined',
		}), {
			'style' => 'white-space:normal;overflow-wrap:anywhere;'.
				'word-break:break-word;vertical-align:top;',
			});
}

# sub sqlite_install_authorizer(dbh)
# Prevents raw SQL from accessing files outside the open database.
sub sqlite_install_authorizer
{
my ($dbh) = @_;
eval { require DBD::SQLite::Constants; };
# Disable direct SQL entirely when the driver cannot enforce the sandbox.
if ($@ || !$dbh->can('sqlite_set_authorizer')) {
	&error($text{'exec_noauthorizer'});
	}
my $ok = DBD::SQLite::Constants::SQLITE_OK();
my $deny = DBD::SQLite::Constants::SQLITE_DENY();
my $attach = DBD::SQLite::Constants::SQLITE_ATTACH();
my $detach = DBD::SQLite::Constants::SQLITE_DETACH();
my $pragma = DBD::SQLite::Constants::SQLITE_PRAGMA();
my $function = DBD::SQLite::Constants::SQLITE_FUNCTION();
# Disable extension loading when the driver exposes the control method.
$dbh->sqlite_enable_load_extension(0)
	if ($dbh->can('sqlite_enable_load_extension'));
# sub authorizer(action, argument1, argument2)
# Denies SQL operations that can reach files outside the approved database.
$dbh->sqlite_set_authorizer(sub {
	my ($action, $arg1, $arg2) = @_;
	# ATTACH and DETACH could bypass the module's database path ACL.
	return $deny if ($action == $attach || $action == $detach);
	# Directory-changing pragmas can redirect SQLite's temporary files.
	return $deny if ($action == $pragma && defined($arg1) &&
		$arg1 =~ /^(?:data|temp)_store_directory$/i);
	# File and extension helpers could read or write arbitrary server paths.
	return $deny if ($action == $function &&
		grep { defined($_) && /^(?:load_extension|readfile|writefile)$/i }
			($arg1, $arg2));
	return $ok;
	});
}

# sub sqlite_query(dbh, sql, [limit])
# Executes one SQL statement and returns its columns, rows and affected-row
# count.
sub sqlite_query
{
my ($dbh, $sql, $limit) = @_;
$limit = int($limit || 0);
# Use one row as the minimum result limit.
$limit = 1 if ($limit < 1);
# Cap retained results at 100,000 rows.
$limit = 100000 if ($limit > 100000);
# The driver prepares the first statement only, and reports what follows
# it just while multiple statements are allowed. Allow them for the
# prepare alone, which runs nothing, then refuse any remainder instead of
# dropping it silently.
$dbh->{'sqlite_allow_multiple_statements'} = 1;
my $sth = eval { $dbh->prepare($sql) };
my $prepare_error = $@;
$dbh->{'sqlite_allow_multiple_statements'} = 0;
die $prepare_error if ($prepare_error);
my $rest = $sth->{'sqlite_unprepared_statements'};
die $text{'exec_multiple'}."\n" if (defined($rest) && $rest =~ /\S/);
$sth->execute();
# Collect result metadata before fetching the bounded set of rows.
my @columns = $sth->{'NAME'} ? @{$sth->{'NAME'}} : ( );
my @rows;
my $truncated;
# Fetch result rows only when the statement exposes result columns.
if (@columns) {
	while (my $row = $sth->fetchrow_arrayref()) {
		# Fetch one extra row to distinguish a full page from
		# truncation.
		if ($limit && @rows >= $limit) {
			$truncated = 1;
			last;
			}
		push(@rows, [ @$row ]);
		}
	}
my $affected = $sth->rows();
$sth->finish();
return {
	'columns' => \@columns,
	'rows' => \@rows,
	'affected' => $affected,
	'truncated' => $truncated,
	};
}

# sub sqlite_column_types()
# Returns the column types offered by the table form, in display order.
sub sqlite_column_types
{
return ( 'INTEGER', 'TEXT', 'REAL', 'BLOB', 'NUMERIC' );
}

# sub sqlite_valid_name(name)
# Returns true for a usable table or column name: non-empty, free of
# control characters and not in SQLite's reserved sqlite_ namespace.
sub sqlite_valid_name
{
my ($name) = @_;
return 0 if (!defined($name) || $name eq '');
return 0 if ($name =~ /[\0-\x1f\x7f]/);
return 0 if ($name =~ /^sqlite_/i);
return 1;
}

# sub sqlite_default_literal(value)
# Returns the SQL literal for a column default typed into the form:
# numbers and the CURRENT_* keywords as they are, NULL as the keyword,
# and any other text as a quoted string.
sub sqlite_default_literal
{
my ($value) = @_;
return 'NULL' if (uc($value) eq 'NULL');
return uc($value) if ($value =~ /^CURRENT_(?:TIME|DATE|TIMESTAMP)$/i);
return $value if ($value =~ /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/);
(my $quoted = $value) =~ s/'/''/g;
return "'".$quoted."'";
}

# sub sqlite_create_table_sql(name, &columns)
# Builds a CREATE TABLE statement from the form's column definitions, or
# dies with a message when the definition is invalid. Each column is a
# hash with name, type, null (1 when NULL is allowed), key ('', 'pk',
# 'pkai' or 'unique') and default (empty for none).
sub sqlite_create_table_sql
{
my ($name, $columns) = @_;
&sqlite_valid_name($name) ||
	die &text('create_ename', &html_escape($name))."\n";
@$columns || die $text{'create_ecolumns'}."\n";
my %types = map { $_ => 1 } &sqlite_column_types();
my (%seen, @pk, $autoincrement);
foreach my $column (@$columns) {
	my $cname = $column->{'name'};
	&sqlite_valid_name($cname) ||
		die &text('create_ecolumn', &html_escape($cname))."\n";
	# Column names are unique without regard to case.
	!$seen{lc($cname)}++ ||
		die &text('create_edup', &html_escape($cname))."\n";
	$types{$column->{'type'}} ||
		die &text('create_etype', &html_escape($cname))."\n";
	push(@pk, $column) if ($column->{'key'} =~ /^pk(ai)?$/);
	$autoincrement = $column if ($column->{'key'} eq 'pkai');
	}
# AUTOINCREMENT needs a lone INTEGER PRIMARY KEY column.
if ($autoincrement && (@pk != 1 || $autoincrement->{'type'} ne 'INTEGER')) {
	die &text('create_eauto', &html_escape($autoincrement->{'name'}))."\n";
	}
my @defs;
foreach my $column (@$columns) {
	my $def = &sqlite_quote_identifier($column->{'name'}).' '.$column->{'type'};
	my $is_pk = $column->{'key'} =~ /^pk(ai)?$/;
	# A single key column is declared on the column itself, so an INTEGER
	# one becomes the rowid alias.
	if ($is_pk && @pk == 1) {
		$def .= ' PRIMARY KEY';
		$def .= ' AUTOINCREMENT' if ($column->{'key'} eq 'pkai');
		}
	# Key columns never allow NULL, which SQLite would otherwise accept in
	# non-INTEGER primary keys.
	$def .= ' NOT NULL' if (!$column->{'null'} || $is_pk);
	$def .= ' UNIQUE' if ($column->{'key'} eq 'unique');
	$def .= ' DEFAULT '.&sqlite_default_literal($column->{'default'})
		if (defined($column->{'default'}) && $column->{'default'} ne '');
	push(@defs, $def);
	}
# Several key columns form one table-level composite key.
push(@defs, 'PRIMARY KEY ('.join(', ',
	map { &sqlite_quote_identifier($_->{'name'}) } @pk).')') if (@pk > 1);
return 'CREATE TABLE '.&sqlite_quote_identifier($name).
	' ('.join(', ', @defs).')';
}

# sub sqlite_supports(feature, [version])
# Returns true when the SQLite library has a feature: rename_column (3.25 and
# later), drop_column (3.35 and later), or full-path nofollow (3.39 and later).
# Here nofollow means that every database path component is checked, not only
# the final filename. version defaults to the loaded library's version number.
sub sqlite_supports
{
my ($feature, $version) = @_;
my %needs = ( 'rename_column' => 3025000, 'drop_column' => 3035000,
	      'nofollow' => 3039000 );
# The driver sets the version once DBD::SQLite is loaded, so load it here
# when nothing has yet; otherwise a check made before the first connection
# would report every feature as missing.
if (!defined($version)) {
	&sqlite_load_driver();
	no warnings 'once';
	$version = $DBD::SQLite::sqlite_version_number;
	}
return $needs{$feature} && $version && $version >= $needs{$feature} ? 1 : 0;
}

# sub sqlite_add_column_sql(table, &column)
# Builds an ALTER TABLE ... ADD COLUMN statement, or dies when SQLite cannot
# add such a column: the name must be valid, the type one of those
# offered, a NOT NULL column needs a constant default to fill existing
# rows, and the default cannot be the current time or date.
sub sqlite_add_column_sql
{
my ($table, $column) = @_;
&sqlite_valid_name($column->{'name'}) ||
	die &text('create_ecolumn', &html_escape($column->{'name'}))."\n";
my %types = map { $_ => 1 } &sqlite_column_types();
$types{$column->{'type'}} ||
	die &text('create_etype', &html_escape($column->{'name'}))."\n";
my $default = defined($column->{'default'}) ? $column->{'default'} : '';
my $has_default = $default ne '' && uc($default) ne 'NULL';
# Existing rows take the default, so NOT NULL is impossible without one.
die $text{'column_enotnull'}."\n" if (!$column->{'null'} && !$has_default);
die $text{'column_ecurrent'}."\n"
	if ($default =~ /^CURRENT_(?:TIME|DATE|TIMESTAMP)$/i);
my $sql = 'ALTER TABLE '.&sqlite_quote_identifier($table).' ADD COLUMN '.
	&sqlite_quote_identifier($column->{'name'}).' '.$column->{'type'};
$sql .= ' NOT NULL' if (!$column->{'null'});
$sql .= ' DEFAULT '.&sqlite_default_literal($default) if ($default ne '');
return $sql;
}

# sub sqlite_table_form(path, &input, count)
# Returns the form for creating a table with the given number of column
# rows, refilled from the submitted values when the form is shown again.
sub sqlite_table_form
{
my ($path, $in, $count) = @_;
my $rv = &ui_form_start('create_table.cgi', 'post');
$rv .= &ui_hidden('db', $path);
$rv .= &ui_hidden('fields', $count);
$rv .= &ui_table_start($text{'create_header'}, 'width=100%', 2);
$rv .= &ui_table_row($text{'create_name'},
	&ui_textbox('name', $in->{'name'}, 40));

# One row of inputs per column, with the first row set up as the usual
# autoincrementing integer key.
my @types = map { [ $_ ] } &sqlite_column_types();
my @keys = (
	[ '', $text{'create_key_none'} ],
	[ 'pk', $text{'create_key_pk'} ],
	[ 'pkai', $text{'create_key_pkai'} ],
	[ 'unique', $text{'create_key_unique'} ] );
my $table = &ui_columns_start([
	$text{'create_column'}, $text{'create_type'}, $text{'create_null'},
	$text{'create_key'}, $text{'create_default'} ], 100, 0,
	[ 'nowrap', 'nowrap', 'nowrap', 'nowrap', 'nowrap' ], undef, 0,
	'no-hover');
# Cells are centered vertically, so the short radio buttons line up with
# the taller text inputs and selects beside them in every theme.
my @cell = ( "nowrap style='vertical-align:middle'" ) x 5;
for(my $i = 0; $i < $count; $i++) {
	my $fresh = !defined($in->{'name_'.$i});
	$table .= &ui_columns_row([
		&ui_textbox('name_'.$i, $in->{'name_'.$i}, 25),
		&ui_select('type_'.$i, $fresh ? ($i ? 'TEXT' : 'INTEGER') :
			$in->{'type_'.$i}, \@types),
		&ui_yesno_radio('null_'.$i, $fresh ? ($i ? 1 : 0) :
			($in->{'null_'.$i} ? 1 : 0)),
		&ui_select('key_'.$i, $fresh ? ($i ? '' : 'pkai') :
			$in->{'key_'.$i}, \@keys),
		&ui_textbox('default_'.$i, $in->{'default_'.$i}, 15),
		], \@cell);
	}
$table .= &ui_columns_end();
$rv .= &ui_table_row(undef, $table, 2);
$rv .= &ui_table_end();
$rv .= &ui_form_end([ [ 'create', $text{'create_ok'} ],
		      [ 'more', $text{'create_more'} ] ]);
return $rv;
}

# sub sqlite_recent_limit()
# Returns how many recently opened databases to keep per user. Zero
# disables the list.
sub sqlite_recent_limit
{
my $limit = $config{'recent'};
# Fall back to three entries when the option is unset or not a number.
$limit = 3 if (!defined($limit) || $limit !~ /^\d+$/);
# Cap the list at fifty entries.
return $limit > 50 ? 50 : int($limit);
}

# sub sqlite_recent_file()
# Returns the file holding the current user's recent list, or undef when
# no user is logged in. Lists live under the module configuration
# directory, which only root can write; once the module runs as a Unix
# user they live in that user's home instead.
sub sqlite_recent_file
{
return undef if (!defined($remote_user) || $remote_user eq '');
my $dir = defined($sqlite_unix_home) && $sqlite_unix_home =~ m!^/! ?
	$sqlite_unix_home.'/.webmin-sqlite' :
	$module_config_directory.'/recent';
# Encoding the name keeps every user in one flat directory, with no
# path separators or dots that could escape it.
return $dir.'/'.&urlize($remote_user);
}

# sub sqlite_read_recent_lines(file)
# Returns the raw lines of a recent list file, newest first.
sub sqlite_read_recent_lines
{
my ($file) = @_;
return () if (!-r $file);
my $data = &read_file_contents($file);
return grep { /\t/ } split(/\r?\n/, defined($data) ? $data : '');
}

# sub sqlite_list_recent()
# Returns the current user's recently opened databases, newest first, as
# hashes with path, time, tables and size. Entries whose file is gone or
# that the current ACL no longer allows are left out.
sub sqlite_list_recent
{
my $file = &sqlite_recent_file();
my $limit = &sqlite_recent_limit();
return () if (!$file || !$limit);
my @recent;
foreach my $line (&sqlite_read_recent_lines($file)) {
	# The path comes last, so a tab inside it survives the split.
	my ($time, $tables, $path) = split(/\t/, $line, 3);
	next if (!defined($path) || $path !~ m!^/!);
	# Check the ACL before touching the file, as the path validator does.
	next if (!&sqlite_path_allowed($path));
	my @st = stat($path);
	# Skip deleted files and anything that is no longer a regular file.
	next if (!@st || !-f _);
	# Tolerate hand-edited or truncated fields without warnings.
	push(@recent, {
		'path' => $path,
		'time' => $time =~ /^\d+$/ ? int($time) : 0,
		'tables' => $tables =~ /^\d+$/ ? int($tables) : undef,
		'size' => $st[7],
		});
	# Stop once the configured number of visible entries is reached.
	last if (@recent >= $limit);
	}
return @recent;
}

# sub sqlite_remember_recent(path, [tables])
# Moves a database to the top of the current user's recent list, keeping
# only the configured number of entries.
sub sqlite_remember_recent
{
my ($path, $tables) = @_;
my $file = &sqlite_recent_file();
my $limit = &sqlite_recent_limit();
return if (!$file || !$limit);
my ($dir) = $file =~ m!^(.*)/[^/]+$!;
# Create the directory on first use, accessible only to the process user.
if (!-d $dir) {
	mkdir($dir, 0700) || return;
	}
&lock_file($file);
# Drop the previous entry for this path, then put the new one first.
my @keep = grep { my @parts = split(/\t/, $_, 3);
		  !defined($parts[2]) || $parts[2] ne $path }
		&sqlite_read_recent_lines($file);
unshift(@keep, time()."\t".int($tables || 0)."\t".$path);
splice(@keep, $limit) if (@keep > $limit);
&write_file_contents($file, join("\n", @keep)."\n");
chmod(0600, $file);
&unlock_file($file);
}

# sub sqlite_forget_recent([path])
# Removes one database from the current user's recent list, or the whole
# list when no path is given.
sub sqlite_forget_recent
{
my ($path) = @_;
my $file = &sqlite_recent_file();
return if (!$file || !-e $file);
&lock_file($file);
my @keep = defined($path) ?
	grep { my @parts = split(/\t/, $_, 3);
	       !defined($parts[2]) || $parts[2] ne $path }
	     &sqlite_read_recent_lines($file) : ( );
# Write the remaining entries back, or drop the file with its last one.
if (@keep) {
	&write_file_contents($file, join("\n", @keep)."\n");
	chmod(0600, $file);
	}
else {
	# Nothing is left to list.
	&unlink_file($file);
	}
&unlock_file($file);
}

# sub sqlite_recent_time(time)
# Formats a last-opened time as today or yesterday with the clock time,
# or as a plain date for older entries.
sub sqlite_recent_time
{
my ($time) = @_;
return '' if (!$time);
my @then = localtime($time);
my @today = localtime(time());
my @yesterday = localtime(time() - 86400);
my $clock = sprintf('%02d:%02d', $then[2], $then[1]);
# Same calendar day as now.
if ($then[5] == $today[5] && $then[7] == $today[7]) {
	return &text('index_today', $clock);
	}
# The calendar day before now.
elsif ($then[5] == $yesterday[5] && $then[7] == $yesterday[7]) {
	return &text('index_yesterday', $clock);
	}
# Older entries show the date only, in the user's date format.
return &make_date($time, 1);
}

1;
