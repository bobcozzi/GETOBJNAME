
CREATE or REPLACE FUNCTION sqltools.GETOBJNAME(
                                   LIBRARY_NAME varchar(128) default '*LIBL',
                                   object_name  varchar(128),
                                   objType      varchar(18)
                                   )
        RETURNS TABLE (
         OBJNAME              VARCHAR(10),
         OBJLIB               VARCHAR(10),
         OBJTYPE              VARCHAR(8),

         LONGOBJNAME          VARCHAR(128),
         LONGOBJLIB           VARCHAR(128),
         SQL_OBJECT_TYPE      VARCHAR(18)
                    )

       LANGUAGE SQL
       READS SQL DATA
       NOT DETERMINISTIC
       SPECIFIC ST_OBJNAME
       CARDINALITY 1

        set option datfmt = *ISO, commit=*NONE

 R: BEGIN

     DECLARE COPYRIGHT  varchar(64) not null default
            '(c) Copyright 2023 by R. Cozzi, Jr. All Rights Reserved.';
     DECLARE WEBSITE    varchar(50) not null default
            'www.SQLiQuery.com/SQLTools';
     DECLARE DESCRIPTION  varchar(50) not null default
            'Get SQL and System Object Name and Type';


     DECLARE isSQLType int not null default 0;
     DECLARE NOT_FOUND int not null default 0;

     DECLARE OBJNAME   varchar(128) NOT NULL DEFAULT '';
     DECLARE OBJLIB    varchar(128) NOT NULL DEFAULT '';
     DECLARE OBJ_TYPE  varchar(18) not null default '';

     DECLARE SYSOBJNAME varchar(10) NOT NULL DEFAULT '';
     DECLARE SYSLIBNAME varchar(10) NOT NULL DEFAULT '';
     DECLARE SYSOBJTYPE varchar(8)  NOT NULL DEFAULT '';

     DECLARE SQOBJNAME varchar(128);
     DECLARE SQLIBNAME varchar(128);
     DECLARE SQOBJTYPE varchar(18) ;

     DECLARE CONTINUE HANDLER FOR NOT FOUND
       SET R.NOT_FOUND = 1;


     if ( LIBRARY_NAME is NOT NULL and LIBRARY_NAME <> '') THEN
        if (LEFT(LIBRARY_NAME,1) <> '"') THEN
          set LIBRARY_NAME = upper(LIBRARY_NAME);
        end if;
        set R.OBJLIB = strip(LIBRARY_NAME,L,' ');
      end if;

      if (OBJECT_NAME is not null and OBJECT_NAME <> '') THEN
        if (LEFT(OBJECT_NAME,1) <> '"') THEN
          set OBJECT_NAME = upper(OBJECT_NAME);
        end if;
        set R.OBJNAME = strip(OBJECT_NAME,L,' ');
      end if;

    if (OBJTYPE is NOT NULL and OBJTYPE <> '') THEN
       set R.OBJ_TYPE = upper(OBJTYPE);
       set R.OBJ_TYPE = strip(R.OBJ_TYPE,B,' ');
     end if;
     if (OBJTYPE is NULL or R.OBJ_TYPE in ('*SAVF','SAVF') or
         R.OBJ_TYPE = '') THEN
       set R.OBJ_TYPE = '*FILE';
     end if;           

       -- Strip off any leading asterisk
     if (LEFT(R.OBJ_TYPE,1) = '*') THEN
       set R.OBJ_TYPE = SUBSTR(R.OBJ_TYPE,2);
     end if;

      -- ----------------------------------------
      -- Check for a valid System Object Type.
      -- ----------------------------------------
      -- BOB: Note we are using the IBM-supplied QSYS2.OBJTYPES
      --      and not our SQLTOOLS.OBJTYPES because IBM has
      --      made QSYS2.OBJTYPES available on V7R2 and later.
      -- ----------------------------------------
      --   Fetch the object type by partial key.
      --   This checks for type PGM instead of *PGM
      --   allowing the caller to specify PGM or *PGM for the
      --   object type (OBJTYPE) parameter.
      -- ----------------------------------------
    if NOT EXISTS (Select * from qsys2.OBJTYPES
            WHERE SUBSTR(OBJECT_TYPE,2) = R.OBJ_TYPE) THEN
       set R.isSQLType = 1;
    end if;

    -- Extract a Sytem Object Name from a long SQL name
     if (R.isSQLType=1) THEN -- Is it an SQL Type vs an OBJTYPE?
        SELECT OBJNAME, rTrim(OBJLONGNAME),
               rTrim(OBJLONGSCHEMA),
               OBJTYPE, SQL_OBJECT_TYPE
          INTO R.SYSOBJNAME, R.SQOBJNAME,
               R.SQLIBNAME,
               R.SYSOBJTYPE, R.SQOBJTYPE
        FROM TABLE(OBJECT_STATISTICS(R.OBJLIB, '*ALL', R.OBJNAME)) OL
         WHERE OL.SQL_OBJECT_TYPE = R.OBJ_TYPE -- select by SQL Type
         LIMIT 1;  -- We only need the first one, so limit the results
     else
        SELECT OBJNAME, rTrim(OBJLONGNAME),
               rTrim(OBJLONGSCHEMA),
               OBJTYPE, SQL_OBJECT_TYPE
          INTO R.SYSOBJNAME, R.SQOBJNAME,
               R.SQLIBNAME,
               R.SYSOBJTYPE, R.SQOBJTYPE
        FROM TABLE(OBJECT_STATISTICS(R.OBJLIB, R.OBJ_TYPE, R.OBJNAME)) OL
        LIMIT 1;
     end if;

          -- To be V7R2 safe, we get the short library name in a 2nd step
     if (R.NOT_FOUND = 0) THEN
       if (length(R.SQLIBNAME) > 10) THEN
        SELECT OBJNAME
            INTO R.SYSLIBNAME
          FROM TABLE(OBJECT_STATISTICS('QSYS', '*LIB', R.SQLIBNAME)) OL;
       else
        set R.SYSLIBNAME = R.SQLIBNAME;
       end if;

       PIPE (
         R.SYSOBJNAME,
         R.SYSLIBNAME,
         R.SYSOBJTYPE,

         CASE WHEN R.SQOBJNAME is NULL or R.SQOBJNAME = '' THEN NULL
              ELSE rTrim(R.SQOBJNAME) END,
         CASE WHEN R.SQLIBNAME is NULL or R.SQLIBNAME = '' THEN NULL
              ELSE rTrim(R.SQLIBNAME) END,
         CASE WHEN R.SQOBJTYPE is NULL or R.SQOBJTYPE = '' THEN NULL
              ELSE rTrim(R.SQOBJTYPE) END
          );
     end if;
     RETURN;
end;
