/*количество посетителей*/
select count(visitor_id) as visitors_count
from sessions;

/*количество посетителей по дням*/

select
    source,
    to_char(visit_date, 'dd') as visit_date,
    count(distinct visitor_id) as visitors_count
from sessions
group by 1, 2;

/*количество посетителей по неделям*/

select
    source,
    to_char(visit_date, 'w') as visit_date,
    count(distinct visitor_id) as visitors_count
from sessions
group by 1, 2;

/*количество посетителей по месяцам*/

select
    source,
    to_char(visit_date, 'MONTH') as visit_date,
    count(distinct visitor_id) as visitors_count
from sessions
group by 1, 2;

/*конверсия из визитов в лид*/

with abc as (
    select
        count(distinct l.lead_id) as leads_count,
        count(distinct s.visitor_id) as visitors_count,
        count(distinct l.lead_id) filter (
            where l.amount > '0'
        ) as purchases_count
    from sessions as s
    full join leads as l
        on s.visitor_id = l.visitor_id
)

select round(leads_count * 100.0 / visitors_count, 5) as click_lead_conversion
from abc;

/*конверсия из лидов в оплату*/

with abc as (
    select
        count(distinct l.lead_id) filter (where l.amount > '0') as leads_pay,
        count(distinct l.lead_id) as leads_count
    from leads as l
)

select round(leads_pay * 100.00 / leads_count, 2) as click_lead_pay
from abc;



/*Кол-во уникальных посетителей, лидов и закрытых лидов для воронки продаж*/

with abc as (
    select
        'visitors' as category,
        count(distinct visitor_id) as counts
    from sessions

    union all

    select
        'leads' as category,
        count(distinct lead_id) as counts
    from leads

    union all

    select
        'purchased_leads' as category,
        count(lead_id) filter (
            where closing_reason = 'Успешно реализовано' or status_id = 142
        ) as counta
    from leads
)

select
    category,
    counts
from abc
order by 2 desc;




/*Окупаемость*/

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
        sum(daily_spent) as daily_spent
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        to_char(campaign_date, 'yyyy.mm.dd') as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads
    group by 1, 2, 3, 4
),

agregation as (
    select
        lv.utm_source,
        lv.utm_medium,
        lv.utm_campaign,
        r.daily_spent as total_cost,
        to_char(lv.visit_date, 'yyyy.mm.dd') as visit_date,
        count(lv.visitor_id) as visitors_count,
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
    group by 1, 2, 3, 4, 5
)

select
    a.utm_source,
    sum(a.total_cost) as sum_costs,
    sum(a.revenue) as revenue
from agregation as a
group by 1
having a.utm_source in ('vk', 'yandex');



/*основные метрики*/

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
        sum(daily_spent) as daily_spent
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        to_char(campaign_date, 'yyyy.mm.dd') as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads
    group by 1, 2, 3, 4
),

agregation as (
    select
        lv.utm_source,
        lv.utm_medium,
        lv.utm_campaign,
        r.daily_spent as total_cost,
        to_char(lv.visit_date, 'yyyy.mm.dd') as visit_date,
        count(lv.visitor_id) as visitors_count,
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
    group by 1, 2, 3, 4, 5
)

select
    a.utm_source,
    a.utm_campaign,
    a.utm_medium,
    coalesce(round(sum(a.total_cost) / sum(a.leads_count), 2), 0) as cpl,
    coalesce(round(sum(a.total_cost) / sum(a.purchases_count), 2), 0) as cppu,
    coalesce(round(sum(a.total_cost) / sum(a.visitors_count), 2), 0) as cpu,
    round(
        (sum(a.revenue) - sum(a.total_cost)) / sum(a.total_cost) * 100.00, 2
    ) as roi
from agregation as a
group by 1, 2, 3
having
    a.utm_source in ('vk', 'yandex')
    and sum(a.leads_count) != 0
    and sum(a.purchases_count) != 0
    and sum(a.visitors_count) != 0;