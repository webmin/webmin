# config_info.pl for certmgr
# do 'certmgr-lib.pl';
require 'certmgr-lib.pl';

sub show_cfile
{
local ($value) = @_;
return "<input name=cfile size=30 value='$value'> ". &file_chooser_button("cfile")." "."<a href='/certmgr/edit_file.cgi?file=$value'>Edit..</a>";
}

sub parse_cfile
{
return $in{'cfile'};
}

