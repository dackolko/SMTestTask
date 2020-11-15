create or replace package utils_pkg is

  procedure add_street(p_name_street varchar2
                      ,p_first_x     number
                      ,p_first_y     number
                      ,p_second_x    number
                      ,p_second_y    number);
  procedure delete_street(p_name streets.name_street%type);
  procedure add_wifi_point(p_name   varchar2
                          ,p_radius number
                          ,p_x      number
                          ,p_y      number);
  procedure delete_point(p_id_point wifipoints.id_point%type);
end utils_pkg;
/
create or replace package body utils_pkg is

  --
  procedure add_street(p_name_street varchar2
                      ,p_first_x     number
                      ,p_first_y     number
                      ,p_second_x    number
                      ,p_second_y    number) is
    l_not_exists exception;
    pragma exception_init(l_not_exists, -00942);
  begin
    insert into streets
      (name_street
      ,first_x
      ,first_y
      ,second_x
      ,second_y
      ,p1
      ,p2)
    values
      (p_name_street
      ,p_first_x
      ,p_first_y
      ,p_second_x
      ,p_second_y
      ,coordinate(p_first_x, p_first_y)
      ,coordinate(p_second_x, p_second_y));
    commit;
  end;
  --
  procedure delete_street(p_id_street streets.id_street%type) is
  begin
    delete from streets
     where id_street = p_id_street;
    commit;
  end;
  --
  procedure delete_street(p_name streets.name_street%type) is
    l_id_street streets.id_street%type;
  begin
    select s.id_street
      into l_id_street
      from streets s
     where s.name_street = p_name;
    delete_street(l_id_street);
  exception
    when no_data_found then
      raise_application_error(-20000, 'No found street');
  end;
  --
  procedure add_wifi_point(p_name   varchar2
                          ,p_radius number
                          ,p_x      number
                          ,p_y      number) is
    l_not_exists exception;
    pragma exception_init(l_not_exists, -00942);
  begin
    insert into wifipoints
      (name_point
      ,radius
      ,x
      ,y
      ,p)
    values
      (p_name
      ,p_radius
      ,p_x
      ,p_y
      ,coordinate(p_x, p_y));
    commit;
  end;
  --
  procedure delete_point(p_id_point wifipoints.id_point%type) is
  begin
    delete from wifipoints
     where id_point = p_id_point;
    commit;
  end;
end utils_pkg;
/