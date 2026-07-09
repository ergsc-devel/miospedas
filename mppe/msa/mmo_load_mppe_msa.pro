;+
; NAME:    mmo_load_mppe_msa
; PURPOSE: Load and plot data from the MPPE/MSA instrument onboard the BepiColombo/MMO spacecraft
; Usage:   mmo_load_msa, level=level, data_mode=data_mode, obs_mode = obs_mode
; Currently only level='l2p' (Lv.2pre) and data_mode='l' (L-mode) are supported.
; With these options, the l-eflux-moments-tof data are loaded by default.
;
; Written by N. Kitamura, ISEE/Nagoya Univ., Japan (email: naritoshi.kitamura _at_ nagoya-u.jp)
; Created: June 29, 2026
;-
pro mmo_load_mppe_msa, $
  level = level, data_mode = data_mode, obs_mode = obs_mode, $
  datatypes = datatypes, $
  varformat = varformat, $
  trange = trange, $
  local_data_dir = local_data_dir, remote_data_dir = remote_data_dir, $
  no_download = no_download, no_update = no_update, latest_version = latest_version, $
  downloadonly = downloadonly, $
  uname = uname, passwd = passwd, $
  tt2000 = tt2000, $
  verbose = verbose, debug = debug
  compile_opt idl2

  if undefined(debug) then debug = 0

  ; ; Default parameters
  if undefined(level) then level = 'l2pre' ; ; Lv.2pre
  if level eq 'l2pre' then level = 'l2p'
  if level eq 'l2p' then leveldir = 'l2pre'
  if undefined(data_mode) then data_mode = 'l' ; ; L-mode
  if undefined(obs_mode) then obs_mode = '' else obs_mode = '-' + obs_mode ; ; empty for L mode
  if undefined(datatype) then datatypes = ['eflux-moments-tof']

  ; ; Initialize the environmental variable and set some parameters for spd_downlaod
  mmo_init
  src = !mmo

  if undefined(local_data_dir) then local_data_dir = src.local_data_dir
  if undefined(remote_data_dir) then remote_data_dir = src.remote_data_dir
  if keyword_set(no_download) then no_download = 1 else $
    no_download = src.no_download or src.no_server or keyword_set(no_update)

; ; Data file path  ;; so far only a scalar datatype is supported.
; ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/mppe/msa/l2pre/l/eflux-moments-tof/2025/08/bc_mmo_mppe-msa_l2p_l-eflux-moments-tof_20250108_r01-v01-01.cdf

  foreach datatype, datatypes do begin
    instdir = 'mppe/msa/'
    case datatype of
      'eflux-moments-tof': datatypedir = 'eflux-moments-tof'
      'omnieflux-moments-tof': datatypedir = 'omnieflux-moments-tof'
      '3deflux': datatypedir = '3deflux'
      'tof': datatypedir = 'tof'
      'event': datatypedir = 'event'
      'moments': datatypedir = 'moments'
      else: begin
        dprint, 'Unsupported datatype: ' + datatype + '! Skip!'
      end
    endcase
    local_path = local_data_dir + instdir + leveldir + '/' + data_mode + obs_mode + '/' + datatypedir + '/'
    remote_path = remote_data_dir + instdir + leveldir + '/' + data_mode + obs_mode + '/' + datatypedir + '/'

    datfn_prefix = 'bc_SAT_mppe-msa_' + level + '_' + data_mode + obs_mode + '-' + datatype + '_'
    relfpathfmt = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_r??-v??-??.cdf'
    relfpaths0 = file_dailynames( file_format = relfpathfmt, trange = trange, /unique, times = times)

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
    vn_prefix = 'mmo_mppe_msa_' + level + '_' + data_mode + obs_mode + '-' + datatype + '_'
    spd_cdf2tplot, file = files_out, prefix = vn_prefix, varformat = varformat, tt2000 = tt2000, verbose = verbose

    ; ; Decorate created tplot variables
    case datatype of
      'eflux-moments-tof': begin
        options, vn_prefix + 'deflux_*', spec = 1, ytitle = 'BC/MMO!CMSA Lv.2pre!Cl-deflux!CEnergy', ysubtitle = '[eV]', /ylog, /zlog
        options, vn_prefix + 'deflux_*', zticklen = -0.4, ytickunits = 'scientific', ztitle = '[eV/cm!U2!N/sr/s/eV]', ztickunits = 'scientific'
      end
      'omnieflux-moments-tof': begin
        options, vn_prefix + 'eflux_*', spec = 1, ytitle = 'BC/MMO!CMSA Lv.2!Cl-omnieflux!CEnergy', ysubtitle = '[eV]', /ylog, /zlog
        options, vn_prefix + 'eflux_*', zticklen = -0.4, ytickunits = 'scientific', ztitle = '[eV/cm!U2!N/sr/s/eV]', ztickunits = 'scientific'
      end
      '3deflux': begin
      end
      'tof': begin
      end
      'event': begin
      end
      'moments': begin
      end
    endcase
  endforeach ; ; the end of the loop for datatype

  return
end
