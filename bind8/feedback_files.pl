
do 'bind8-lib.pl';

sub feedback_files
{
local @rv = ( &make_chroot($config{'named_conf'}) );
local $conf = &get_config();
local @views = &find("view", $conf);
local @zones;
foreach $v (@views) {
	push(@zones, &find("zone", $v->{'members'}));
	}
push(@zones, &find("zone", $conf));
foreach $z (@zones) {
	local $tv = &find("type", $z->{'members'});
	if ($tv->{'value'} eq 'primary') {
		local $fv = &find("file", $z->{'members'});
		if ($fv) {
			push(@rv, $fv->{'value'});
			}
		}
	}
return @rv;
}

1;

