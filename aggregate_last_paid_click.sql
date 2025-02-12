with rn_click as (
    select
        s.visitor_id,
        s.visit_date::date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as rn
    from sessions as s
    where s.medium != 'organic'
)
,

last_visit as (
    select *
    from rn_click
    where rn = 1
),

rekl as (
    select
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads
    group by 1, 2, 3, 4
)

select
    lv.visit_date as visit_date,
    lv.utm_source,
    lv.utm_medium,
    lv.utm_campaign,
    count(lv.visitor_id) as visitors_count,
    (r.daily_spent) as total_cost,
    count(l.lead_id) as leads_count,
    count(l.lead_id) filter (
        where l.closing_reason = 'Успешно реализовано' or l.status_id = '142'
    ) as purchases_count,
    sum(l.amount) as revenue
from last_visit as lv
left join leads as l
    on
        lv.visitor_id = l.visitor_id
        and lv.visit_date <= l.created_at
left join rekl as r
    on
        lv.utm_campaign = r.utm_campaign
        and lv.utm_medium = r.utm_medium
        and lv.utm_source = r.utm_source
        and r.campaign_date = lv.visit_date::date
group by 1, 2, 3, 4, 6
order by
    9 desc nulls last,
    1 asc,
    5 desc,
    3 asc,
    4 asc,
    2 asc
limit 15;
