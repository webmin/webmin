# mod_dir.pl
# Defines editors for mod_dir directives

sub mod_dir_directives
{
local($rv, $all); $all = 'virtual directory htaccess';
$rv = [ [ 'DirectoryIndex', 0, 12, 'virtual directory htaccess', undef, 8 ],
	[ 'AddIcon AddIconByType AddIconByEncoding', 1, 12, $all, -1.3, 1 ],
        [ 'DefaultIcon', 0, 12, $all, -1.3, 4 ],
        [ 'AddAlt AddAltByType AddAltByEncoding', 1, 12, $all, -1.3 ],
        [ 'AddDescription', 1, 12, $all, -1.3 ],
        [ 'IndexOptions FancyIndexing', 0, 12, $all, -1.3, 10 ],
        [ 'HeaderName', 0, 12, $all, -1.3, 3 ],
        [ 'ReadmeName', 0, 12, $all, -1.3, 2 ],
        [ 'IndexIgnore', 1, 12, $all, -1.3, 6 ] ];
return &make_directives($rv, $_[0], "mod_dir");
}

sub edit_DirectoryIndex
{
local($rv);
$rv = sprintf "<textarea name=DirectoryIndex rows=5 cols=20>%s</textarea>\n",
        join("\n", split(/\s+/, $_[0]->{'value'}));
return (1, "$text{'mod_dir_txt'}", $rv);
}
sub save_DirectoryIndex
{
local(@di);
@di = split(/\s+/, $in{'DirectoryIndex'});
return @di ? ( [ join(' ', @di) ] ) : ( [ ] );
}

require 'autoindex.pl';

1;

