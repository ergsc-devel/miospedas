;+
;
; mmo_load_spm
;
; Load BC/MMO SPM data for use on IDL/SPEDAS
;
; Currently only Lv.2pre count data are available, and most
; options are unavailable or simply not used. The usage of avaialble
; options are described below.
;
; trange: Set a time range (e.g., ['2021-8-10','2021-8-11']) for loading data
; local_data_dir: a directory in which downloaded data files are saved
; remote_data_dir: Set to explicitly download data files from another online repository
; uname, passwd: ID and password to access the online data repository
; no_download: Set to skip downloading data files from the data repository
; no_update: the same as no_download, added for compatibility
; downloadonly: Set to download data files but skip creating tplot variables
;
; :Examples:
;   IDL> mmo_init
;   MMO> timespan, '2021-08-10', 1, /day
;   MMO> mmo_load_spm, uname='?????', pass='?????'  ;; Needs ID/pass for accessing Lv.2pre data
;   MMO> tplot, 'mmo_spm_l2p_spm1_lv?_cnt'
;
; :History:
; 2023/09/01: first protetype
; 2025/02/25: 1st release ver.
;
;-
pro mmo_load_spm, $
  level = level, data_mode = data_mode, obs_mode = obs_mode, $
  datatypes = datatypes, $
  varformat = varformat, $
  trange = trange, $
  get_support_data = get_support_data, $
  local_data_dir = local_data_dir, remote_data_dir = remote_data_dir, $
  uname = uname, passwd = passwd, $
  no_download = no_download, no_update = no_update, latest_version = latest_version, $
  downloadonly = downloadonly, $
  tt2000 = tt2000, $
  verbose = verbose, debug = debug
  compile_opt idl2

  if undefined(debug) then debug = 0

  ; ; Default parameters
  if undefined(level) then level = 'l2p' ; ; Lv.2pre
  if level eq 'l2pre' then level = 'l2p'
  if level eq 'l2p' then leveldir = 'l2pre'
  if undefined(data_mode) then data_mode = 'l' ; ; L-mode
  if undefined(obs_mode) then obs_mode = '' ; ; empty for MS mode
  if undefined(datatype) then datatypes = ['cnt']

  ; ; Initialize the environmental variable and set some parameters for spd_downlaod
  mmo_init
  src = !mmo

  if undefined(local_data_dir) then local_data_dir = src.local_data_dir
  if undefined(remote_data_dir) then remote_data_dir = src.remote_data_dir
  if keyword_set(no_download) then no_download = 1 else $
    no_download = src.no_download or src.no_server or keyword_set(no_update)

  ; ; Data file path  ;; so far only a scalar datatype is supported.
  ; ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/spm/l2pre/cnt/2021/08/bc_mmo_spm_l2p_cnt_20210810_r00-v00-00.cdf

  foreach datatype, datatypes do begin
    instdir = 'spm/'
    local_path = local_data_dir + instdir + leveldir + '/' + datatype + '/'
    remote_path = remote_data_dir + instdir + leveldir + '/' + datatype + '/'

    datfn_prefix = 'bc_SAT_spm_' + level + '_' + datatype + '_'
    relfpathfmt = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_r??-v??-??.cdf'
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
      local_path = local_path $
      , remote_path = remote_path, remote_file = relfpaths $
      , last_version = latest_version, no_download = no_download $
      , no_update = no_update $
      , url_username = uname, url_password = passwd $
      )

    id = where(file_test(files_out), nid)
    if nid eq 0 then begin
      dprint, 'Cannot find any data file! Exit!'
      return
    endif
    files_out = files_out[id] ; ; only existing files are processed below
    if debug then dprint, 'files_out: ' + files_out

    ; ; Read CDF files to generate tplot variables
    vn_prefix = 'mmo_spm_' + level + '_'
    spd_cdf2tplot, file = files_out, prefix = vn_prefix, varformat = varformat, get_support_data = get_support_data, tt2000 = tt2000, verbose = verbose

    ; ; Decorate created tplot variables
    case level of
      'l2p': begin
        case datatype of
          'cnt': begin ; ; mmo_spm_l2p_spm1_lv1_cnt
            options, 'mmo_spm_l2p_spm1_lv1_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM1 Lv1', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm1_lv2_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM1 Lv2', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm1_lv3_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM1 Lv3', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm1_lv4_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM1 Lv4', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm2_lv1_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM2 Lv1', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm2_lv2_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM2 Lv2', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm2_lv3_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM2 Lv3', ysubtitle = '[cnt/smpl]'
            options, 'mmo_spm_l2p_spm2_lv4_cnt', ytitle = 'BC/MMO!CSPM Lv2pre!CSPM2 Lv4', ysubtitle = '[cnt/smpl]'
          end
        endcase
      end
    endcase
  endforeach ; ; the end of the loop for datatype

  return
end
