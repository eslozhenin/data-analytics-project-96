/*Витрина для модели атрибуции Last Paid Click*/

with rn_click as (
    select
        s.visitor_id,
        s.visit_date,
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
)

select
    lv.visitor_id,
    lv.visit_date,
    lv.utm_source,
    lv.utm_medium,
    lv.utm_campaign,
    l.lead_id,
    l.created_at,
    sum(l.amount) over (partition by lv.visitor_id) as amount,
    l.closing_reason,
    l.status_id
from last_visit as lv
left join leads as l
    on
        lv.visitor_id = l.visitor_id
        and lv.visit_date <= l.created_at
order by
    amount desc nulls last,
    lv.visit_date asc,
    lv.utm_source asc,
    lv.utm_medium asc,
    lv.utm_campaign asc
limit 10;
