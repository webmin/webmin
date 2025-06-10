
do 'xinetd-lib.pl';

sub feedback_files
{
local $conf = &get_xinetd_config();
return &unique(map { $_->{'file'} } @$conf);
}

1;

