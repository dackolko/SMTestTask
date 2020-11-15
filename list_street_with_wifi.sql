create or replace view list_street_with_wifi as 
with calc_dist_to_p as
 (select s.id_street
        ,p.id_point
        ,p.name_point
        ,utils_pkg.dist_to_line(p_p => p.p, p_p1 => s.p1, p_p2 => s.p2) dist_to_p
        ,p.radius
        ,s.name_street
        ,s.p1
        ,s.p2
        ,p.p
    from streets    s
        ,wifipoints p),
get_min_dist as
 (select id_street, name_street,id_point, name_point, radius, dist_to_p
        ,min(dist_to_p) over(partition by id_point) min_dist
    from calc_dist_to_p d)
select id_street, name_street,id_point, name_point, radius, dist_to_p
  from get_min_dist
  where min_dist=dist_to_p and radius > dist_to_p;