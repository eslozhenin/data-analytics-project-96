/*Расходы на рекламу по модели атрибуции Last Paid Click*/

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
),

rekl as (
    select
        to_char(campaign_date, 'yyyy.mm.dd') as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        coalesce(sum(ya.daily_spent), 0)
        + coalesce(sum(vk.daily_spent), 0) as summa
    from vk_ads as vk
    full join ya_ads as ya
        using(utm_campaign, utm_medium, utm_source, campaign_date)
    group by 1, 2, 3, 4
)

select
    to_char(lv.visit_date, 'yyyy.mm.dd') as visit_date,
    lv.utm_source,
    lv.utm_medium,
    lv.utm_campaign,
    count(lv.visitor_id) as visitors_count,
    coalesce(r.summa, 0) as total_cost,
    count(l.lead_id) as leads_count,
    count(l.lead_id) filter (
        where l.closing_reason = 'Успешная продажа' or l.status_id = '143'
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
        and r.campaign_date = to_char(lv.visit_date, 'yyyy.mm.dd')
group by 1, 2, 3, 4, 6
order by
    revenue desc nulls last,
    visit_date asc,
    visitors_count desc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 15;