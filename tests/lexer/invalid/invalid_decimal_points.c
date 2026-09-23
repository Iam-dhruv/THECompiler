/* More than one '.' inside a single numeric run can never be a valid
   constant. Caught lexically as one bad token, not as several good ones. */
float a = 1.2.3.4;
float b = 1.5.5;
float c = 1..2;

/* Leading '..' are separate T_DOT tokens; the last '.' binds to the digits,
   producing the malformed number ".1231.131". */
float d = ...1231.131;
