create or replace table chmedia.subs_session_first_page_jan22 as (

    with logs as (
     select
        datetime(timestamp(data.ingress.initTS),"Europe/Berlin") as time,
        date(time,"Europe/Berlin") as day_dt,
        right(left(publish_path,8),3) as portal,
        ifnull(
            data.digitalData.user.list[offset(0)].element.profile.list[offset(0)].element.profileInfo.profileID,
            data.ingress.vIDc) as user_id,
        ifnull(data.digitalData.user.list[offset(0)].element.profile.list[offset(0)].element.attributes.c1.subscriptionStatus = "true",false) as is_sub,
        data.ingress.session.initSessionID as session_id,
        data.ingress.navigator.isMobile.any as is_mobile,
        length(publish_path) = 8 as is_web,
        data.ingress.referrer
    from chmedia.logs
    where date(time,"Europe/Berlin") >= "2022-01-03"
        and date(time,"Europe/Berlin") <= "2022-01-30"
        and (length(publish_path) = 8 or publish_path like "%news")
        and not data.ingress.navigator.isMobile.any is null
        and not data.ingress.session.initSessionID is null
        and not data.ingress.vIDc is null
    ),

    indexed_pages as (
        select
            *,
            row_number() over(partition by day_dt, session_id order by time asc) as page_index
        from logs
        where is_web is False
    ),

    session_starts as (
        select
            *,
            array_reverse(split(net.host(referrer),"."))[safe_offset(1)] as domain,
            array_reverse(split(net.host(referrer),"."))[safe_offset(2)] as sub_domain,
            array_reverse(split(net.host(referrer),"."))[safe_offset(0)] as toplevel_domain,
            split(split(referrer,"?")[safe_offset(0)],"/")[safe_offset(3)] as first_path,
            LENGTH(referrer) - LENGTH(REGEXP_REPLACE(referrer, '/', '')) - 2 as n_path_parts
        from indexed_pages
        where page_index = 1
    ),

    domain_classes as (
        select
            * except(page_index),
            row_number() over(partition by day_dt, user_id order by time asc) as session_index,
            case
                when referrer is null then "dark"
                when domain in (
                    "tagblatt","oltnertagblatt","luzernerzeitung","aargauerzeitung","grenchnertagblatt","solothurnerzeitung",
                    "limmattalerzeitung","bzbasel", "badenertagblatt")
                then "internal"
                else "external"
            end as domain_class
        from session_starts
    ),

    referrer_class as(
        select
            *,
            right("0"||cast(extract(hour from time) as string),2) || ":" ||
              right("0"||cast(cast(floor(extract(minute from time)/15)*15 as integer) as string),2)  as time_bin,
            case
                when referrer is null or length(referrer)=0 then "dark"
                when domain_class = "internal" and sub_domain = "www" and (length(first_path) = 0 or first_path is null) then "int:home"
                when domain_class = "internal" and referrer like "%ld.%" then "int:article"
                when domain_class = "internal" then "int:other"
                when domain_class = "external" and (
                    domain in ("google","bing","duckduckgo","ecosia","ampproject")
                    or referrer = "android-app://com.google.android.googlequicksearchbox/"
                ) then "ext:search"
                when domain_class = "external" and domain in ("facebook","t","twitter","linkedin") then "ext:social"
                else "ext:other"
            end as referrer_class
        from domain_classes
    )

    select * except(time,domain,toplevel_domain,sub_domain,first_path,n_path_parts) from referrer_class

)
