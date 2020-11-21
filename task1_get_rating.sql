create or replace force view task1_get_rating as 
select name_street
      ,listagg(name_point, ',') within group(order by null) list_point
      ,count(1) cnt_point
  from list_street_with_wifi
 group by name_street
 order by cnt_point desc;