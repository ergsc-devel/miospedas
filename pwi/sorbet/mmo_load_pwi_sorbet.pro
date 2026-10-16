;+
; PRO mmo_load_pwi_sorbet
;
; The read program for Level-2 PWI/SORBET data (test purpose!)
;
; :Keywords:
;   level: level of data products. Currently only 'l2p' is acceptable.
;   datatypes: types of data products. Currently only 'tnr-e' is acceptable.
;   data_mode: types of mode. Currently 'lm' is available.
;   ;obs_mode: types of observational mode. There are two obs modes: ms (magnetosphere) and sw (solar wind) 
;   varformat: If set a string with wildcards, only variables with
;              matching names are extrancted as tplot variables.
;   get_suuport_data: Set to load support data in CDF data files.
;   trange: Set a time range to load data explicitly for the specified
;           time range.
;   downloadonly: If set, data files are downloaded and the program
;                exits without generating tplot variables.
;   no_download: Set to prevent the program from searching in the
;                remote server for data files.
;   verbose:  Set to make some commands in this program verbose.
;   uname: user ID to be passed to the remote server for
;          authentication.
;   passwd: password to be passed to the remote server for
;           authentication.
;   ror: If set a string, rules of the road (RoR) for data products
;        are displayed at your terminal.
;
; :Examples:
;   IDL> timespan, '2024-09-03'
;   IDL> mmo_load_pwi_sorbet, no_download
;   IDL> mmo_load_pwi_sorbet, datatype='tnr-e', mode= 'lm'
;
; :Authors:
;   N. Kitamura, Center of Heliospheric Science (E-mail: naritoshi.kitamura@nagoya-u.jp)
;
; $LastChangedDate$
; $LastChangedRevision$
;-

pro mmo_load_pwi_sorbet, $

  level           = level, $
  datatypes       = datatypes, $
  data_mode       = data_mode, $
  obs_mode        = obs_mode, $
  trange          = trange, $
  downloadonly    = downloadonly, $
  no_download     = no_download, $
  no_update       = no_update, $
  latest_version  = latest_version, $
  version         = version, $
  get_support_data = get_support_data, $
  varformat       = varformat, $
  tt2000          = tt2000, $
  verbose         = verbose, $
  uname           = uname, $
  passwd          = passwd, $
  debug           = debug, $
  ror             = ror, $
  _extra          = _extra

  compile_opt idl2

  ; --- Default parameters ---
  if undefined(level)     then level     = 'l2p'
  if undefined(data_mode) then data_mode = 'lm'
  if undefined(obs_mode)  then obs_mode  = ''       ; empty = MS mode
  if undefined(datatypes)  then datatypes = ['tnr-e'] else datatypes = datatypes

  if undefined(debug) then debug = 0
  
  if undefined(latest_version) then latest_version = 1
  if not undefined(version) then begin
    latest_version = 0
  endif else begin
    version = 'r??-v??-??'
  endelse
  
  if level eq 'l2' then leveldir = 'l2'
  if level eq 'l2p' then leveldir = 'l2pre'
  
  ;; Initialize the environmental variable and set some parameters for spd_downlaod
  mmo_init
  src = !mmo
  
  if undefined(local_data_dir) then local_data_dir = src.local_data_dir
  if undefined(remote_data_dir) then remote_data_dir = src.remote_data_dir
  if keyword_set(no_download) then no_download = 1 else $
     no_download = src.no_download or src.no_server or keyword_set(no_update)

  ;; Data file path  ;; so far only a scalar datatype is supported.
  ;; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/pwi/sorbet/l2pre/lm/tnr-e/2025/04/bc_mmo_pwi-sorbet_l2p_lm-tnr-e_20250410_r00-v00-02.cdf

  foreach datatype, datatypes do begin

    instdir = 'pwi/sorbet/'
    local_path =   local_data_dir + instdir + leveldir + '/' + data_mode + '/' + datatype + '/' 
    remote_path = remote_data_dir + instdir + leveldir + '/' + data_mode + '/' + datatype + '/'
    
    ; ; Build relative file path pattern
    ; ; e.g. bc_mmo_pwi-sorbet_l2p_lm-tnr-e_20230228_r??-v??-??.cdf
    datfn_prefix = 'bc_SAT_pwi-sorbet_' + level + '_' + data_mode + '-' + datatype + '_'
    relfpathfmt = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_'+version+'.cdf'

    relfpaths0 = file_dailynames( $
      file_format = relfpathfmt $
      , trange = trange, /unique, times = times)

    relfpaths = str_sub(relfpaths0, '_SAT_', '_mmo_') ; ; because "mm" is replaced with a minute value!

    ; ; Download data files from a remote data repository
    if debug then begin
      dprint, 'relfpaths: ' + relfpaths
      dprint, 'remote_path: ' + remote_path
      dprint, 'local_path: ' + local_path
    endif
    files_out = spd_download_plus( $
      local_path = local_path, $
      remote_path = remote_path, $
      remote_file = relfpaths, $
      last_version = latest_version, $
      no_download = no_download, $
      no_update = no_update, $
      url_username = uname, $
      url_password = passwd $
      )

    id = where(file_test(files_out), nid)
    if nid eq 0 then begin
      dprint, 'Cannot find any data file! Exit!'
      return
    endif
    files_out = files_out[id] ; ; only existing files are processed below
    if debug then dprint, 'files_out: ' + files_out

    if keyword_set(downloadonly) then continue

    ; ; Read CDF files to generate tplot variables
    vn_prefix = 'mmo_pwi-sorbet_' + level + '_' + data_mode + '-' + datatype + '_'
    spd_cdf2tplot, file = files_out, prefix = vn_prefix, varformat = varformat, get_support_data = get_support_data, tt2000 = tt2000, verbose = verbose


    ;; Decorate created tplot variables
    case datatype of

      'tnr-e': begin
        options, vn_prefix + ['E?_power*', 'cross_?'], spec = 1, ysubtitle = '[Hz]', /ylog, /zlog, zticklen = -0.4, ytickunits = 'scientific', ztickunits = 'scientific'
        options, vn_prefix + 'E?_power', ztitle = '[mV!U2!N/m!U2!N/Hz]'
        options, vn_prefix + 'E?_power_db', ztitle = '[mV!U2!N/m!U2!N/Hz]'
        options, vn_prefix + 'E?_power_v2', ztitle = '[V!U2!N/Hz]'
        options, vn_prefix + 'Eu_power*', ytitle = 'BC/MMO!CPWI-SORBET L2pre!CEu_tnr-e'
        options, vn_prefix + 'Ev_power*', ytitle = 'BC/MMO!CPWI-SORBET L2pre!CEv_tnr-e'
        options, vn_prefix + 'EuEv_cross_r', ytitle = 'BC/MMO!CPWI-SORBET L2pre!CEuEv cross_r!Ctnr-e'
        options, vn_prefix + 'EuEv_cross_i', ytitle = 'BC/MMO!CPWI-SORBET L2pre!CEuEv cross_i!Ctnr-e'
      end

    endcase

    gatt=cdf_var_atts(files_out[0])

    print_str_maxlet, ' '
    print, '**********************************************************************'
    print_str_maxlet, gatt.LOGICAL_SOURCE_DESCRIPTION, 80
    print, ''
    print, 'Information about MIO PWI SORBET'
    print, ''
    print, 'PI: ', gatt.PI_NAME
    print_str_maxlet, 'Affiliation: '+gatt.PI_AFFILIATION, 80
    print, ''

  endforeach  ;; the end of the loop for datatypes
    
    return
  end
