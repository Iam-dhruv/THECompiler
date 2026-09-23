/* Every numeric literal form this language accepts.
   Guards the "preprocessing number" rule against over-rejection: each of
   these must survive classify_ppnumber() and emerge as a single
   T_INT_CONST or T_FLOAT_CONST token. */
int main() {
    int zero        = 0;
    int dec         = 42;
    int big         = 2147483647;
    int hex_lower   = 0xff;
    int hex_upper   = 0XFF;
    int hex_mixed   = 0xAbCdEf;
    int hex_one     = 0x0;

    float trailing_dot  = 1.;
    float leading_dot   = .5;
    float both_parts    = 3.14;
    float exp_plain     = 1e10;
    float exp_caps      = 1E5;
    float exp_plus      = 2.5e+3;
    float exp_minus     = 2.5e-3;
    float dot_exp       = .5e2;
    float trail_dot_exp = 1.e3;
    return 0;
}
