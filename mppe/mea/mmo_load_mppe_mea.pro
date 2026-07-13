;+
; NAME:    mmo_load_mppe_mea
; PURPOSE: Load and plot electron data from the MPPE/MEA instrument onboard the BepiColombo/MMO spacecraft
; Usage:   mmo_load_mppe_mea, level=level, sensor=sensor, data_mode=data_mode, datatypes=datatypes
; Currently only level='l2p' (Lv.2pre) and data_mode='l' (L-mode) are supported.
;
; Written by T. Hori, ISEE/Nagoya Univ., Japan (email: tomo.hori _at_ nagoya-u.jp)
; Created: Jun. 28, 2026
;-
pro mmo_load_mppe_mea, $
  level = level, data_mode = data_mode, sensor = sensor, enestep = enestep, $
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
  if undefined(level) then level = 'l2p' ; ; Lv.2pre
  if level eq 'l2pre' then level = 'l2p'
  if level eq 'l2p' then leveldir = 'l2pre'
  if undefined(data_mode) then data_mode = 'l' ; ; L-mode
  if undefined(datatypes) then datatypes = ['3dflux', 'omniflux']
  if undefined(sensor) then sensor = 'mea1' ; ; mea1 or mea2
  if undefined(enestep) then enestep = '16' ; 16

  ; ; Initialize the environmental variable and set some parameters for spd_downlaod
  mmo_init
  src = !mmo

  if undefined(local_data_dir) then local_data_dir = src.local_data_dir
  if undefined(remote_data_dir) then remote_data_dir = src.remote_data_dir
  if keyword_set(no_download) then no_download = 1 else $
    no_download = src.no_download or src.no_server or keyword_set(no_update)

  ; ; Data file path  ;; so far only a scalar datatype is supported.
  ; ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/mppe/mea/l2pre/flux/2021/10/bc_mmo_mppe-mea1_l2p_l-omniflux-16e_20211001_r01-v00-00.cdf

  foreach datatype, datatypes do begin
    instdir = 'mppe/mea/'
    case datatype of
      'omniflux': datatypedir = 'flux'
      '3dflux': datatypedir = 'flux'
      else: begin
        dprint, 'Unsupported datatype: ' + datatype + '! Skip!'
        datatype = '' ; ; to skip the following processing
      end
    endcase
    if datatype eq '' then continue

    local_path = local_data_dir + instdir + leveldir + '/' + datatypedir + '/'
    remote_path = remote_data_dir + instdir + leveldir + '/' + datatypedir + '/'

    datfn_prefix = 'bc_SAT_mppe-' + sensor + '_' + level + '_' + data_mode + '-' + datatype + '-' + enestep + 'e_'
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
    vn_prefix = 'mmo_' + sensor + '_' + level + '_' + data_mode + '-' + datatype + enestep + 'e_'
    spd_cdf2tplot, file = files_out, prefix = vn_prefix, varformat = varformat, tt2000 = tt2000, verbose = verbose

    ; ; Decorate created tplot variables
    case datatype of
      'omniflux': begin
        vn = vn_prefix + 'omni_deflux'
        options, vn, spec = 1, ytitle = 'BC/MMO!C' + strupcase(sensor) + '!CLv2pre omni!Cene flux', ysubtitle = '[eV]', ztitle = '[eV/cm!U2!N/sr/s/eV]'
        ylim, vn, 0, 0, 1
        zlim, vn, 0, 0, 1
        options, vn, zticklen = -0.4, ytickunits = 'scientific', ztickunits = 'scientific'
      end
      '3dflux': begin
        vn = vn_prefix + 'deflux'
        options, vn, spec = 1, ytitle = 'BC/MMO!C' + strupcase(sensor) + '!CLv2pre 3D!Cene flux', ysubtitle = '[eV]', ztitle = '[eV/cm!U2!N/sr/s/eV]'
        ylim, vn, 0, 0, 1
        zlim, vn, 0, 0, 1
        options, vn, zticklen = -0.4, ytickunits = 'scientific', ztickunits = 'scientific'
      end
    endcase
  endforeach ; ; the end of the loop for datatype

  return
end
