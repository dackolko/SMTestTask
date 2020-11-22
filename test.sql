begin
  utils_pkg.add_street(p_name_street => 'first', p_first_x => 1, p_first_y => 1, p_second_x => 4, p_second_y => 2);
  utils_pkg.add_street(p_name_street => 'second', p_first_x => 1, p_first_y => 3, p_second_x => 5, p_second_y => 3);
  utils_pkg.add_street(p_name_street => 'three', p_first_x => 3, p_first_y => 1, p_second_x => 3, p_second_y => 4);
  utils_pkg.add_wifi_point(p_name => 'A', p_radius => 3, p_x => 2, p_y => 2);
  utils_pkg.add_wifi_point(p_name => 'B', p_radius => 4, p_x => 1, p_y => 1.5);
  utils_pkg.add_wifi_point(p_name => 'C', p_radius => 5, p_x => 1, p_y => 3.5);
end;
/
--1e
select * from task1_get_rating;
--2e
select * from table(utils_pkg.get_optimal_way(coordinate(1, 4), coordinate(3, 1)));