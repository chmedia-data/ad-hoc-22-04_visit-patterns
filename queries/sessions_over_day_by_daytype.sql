select
    time_bin,
    if( extract(dayofweek from day_dt) in (7,1),"weekend","weekday") as day_type,
    is_sub,
    is_mobile,
    count(*)
from chmedia.subs_session_first_page_jan22
group by 1,2,3,4
