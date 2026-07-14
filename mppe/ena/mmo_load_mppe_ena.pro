;+
;PROCEDURE: mmo_load_mppe_ena
;
;PURPOSE:
;  Loads BepiColombo MMO MPPE-ENA data.
;
;KEYWORDS:
;
;EXAMPLE:
;  IDL> timespan, '20200409'
;  IDL> mmo_load_mppe_ena, level='l2p', data_mode='l', obs_mode='mass', np=1, nm=4 ; load data for mass accumulation mode with 1 spin phase bins and 4 mass bins
;
;NOTE:
;
;HISTORY:
;  2026-02-23: Drafted by Kazuhiro Yamamoto, ISEE, Nagoya University (yamamoto.kazuhiro.s4@f.mail.nagoya-u.ac.jp)
;
;-

pro mmo_load_mppe_ena, $
  level            = level,            $ ; data processing level ('l2p','l2pre','l2')
  data_modes       = data_modes,       $ ; data rate ('l')
  obs_modes        = obs_modes,        $ ; observational mode ('mass', 'cnt')
  nphases          = nphases,          $ ; number of spin phase bin (1, 2, 4, 8, 16)
  nmasses          = nmasses,          $ ; number of mass bin (1, 2, 4, 8)
  datatypes        = datatypes,        $ ; data type ('cnt','flux')
  varformat        = varformat,        $ ; 
  trange           = trange,           $ ; time range for loading data
  get_support_data = get_support_data, $ ; If set, support data in CDF files are loaded.
  local_data_dir   = local_data_dir,   $ ; local data directory in your PC
  remote_data_dir  = remote_data_dir,  $ ; remote data directory in the Mio Science Center server
  local_file       = local_file,       $ ; If set, local files are loaded.
  uname            = uname,            $ ; user name for file access
  passwd           = passwd,           $ ; password for file access 
  no_download      = no_download,      $ ;
  no_update        = no_update,        $ ; 
  latest_version   = latest_version,   $ ; If set, the latest version is downloaded.
  version          = version,          $ ; data version 'r??-v??-??', r?? = release, v?? = major, ?? = minor
  downloadonly     = downloadonly,     $ ;
  tt2000           = tt2000,           $ ;
  verbose          = verbose,          $ ;
  debug            = debug               ; Set if you want to show messages for debug.

  ; Set IDL compile option

  compile_opt idl2

  ; Load leap second table
  cdf_leap_second_init ; this line is needed? Should be added to mmo_init.

  ; Set parameters

  ; Set default parameters
  if undefined(debug     ) then debug      = 0
  if undefined(level     ) then level      = 'l2p'          ; Lv.2pre
  if undefined(data_modes) then data_modes = ['l']          ; L-mode
  if undefined(obs_modes ) then obs_modes  = ['mass','cnt'] ; mass and count accumulation modes
  if undefined(datatypes ) then datatypes  = ['flux']       ; three dimensional velocity distribution of count
  if undefined(nphases    ) then nphases   = [1,2,4,8,16]   ; spin phase bin size
  if undefined(nmasses    ) then nmasses   = [1,2,4,8]      ; mass bin size
  if undefined(latest_version) then latest_version = 1
  if keyword_set(version) then begin
    latest_version = 0
  endif else begin
    version = 'r??-v??-??'
  endelse
  ; modify the parameters
  level      = strlowcase(level)
  data_modes = strlowcase(data_modes)
  obs_modes  = strlowcase(obs_modes)
  datatypes  = strlowcase(datatypes)
  nphases    = string(nphases,format='(i2.2)') ; to string
  nmasses    = string(nmasses,format='(i2.2)') ; to string
  ; unify the data processing level name (l*pre or l*p) 
  case level of
    'l1pre': level = 'l1p'
    'l2pre': level = 'l2p'
    'l3pre': level = 'l3p'
    'l4pre': level = 'l4p'
    else   : level = level
  endcase
  ; directory name for data processing level
  case level of
    'l1p': leveldir = 'l1pre'
    'l2p': leveldir = 'l2pre'
    'l3p': leveldir = 'l3pre'
    'l4p': leveldir = 'l4pre'
    else : leveldir = level
  endcase
  ; data processing level for PDS
  case level of 
    'l1' : proc_lv = 'raw'
    'l1p': proc_lv = 'raw'
    'l2' : proc_lv = 'cal'
    'l2p': proc_lv = 'cal'
    'l3p': proc_lv = 'der'
    'l3' : proc_lv = 'der'
    'l4p': proc_lv = 'der'
    'l4' : proc_lv = 'der'
    else : begin
      dprint, 'Invalid input. level:', level
      dprint, 'Return.'
      return
    end
  endcase

  ; Initialize the environmental variable and set some parameters for spd_downlaod 
  mmo_init ; !mmo is created by MMO_INIT.
  
  ; Set local and remote data directories
  if undefined( local_data_dir) then  local_data_dir = !mmo.local_data_dir  ; root_data_dir()+'chs/satellite/mmo/cdf/', root_data_dir() = '~/data/' in default
  if undefined(remote_data_dir) then remote_data_dir = !mmo.remote_data_dir ; 'https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/'

  ; Set keyword for downloading data files
  if keyword_set(no_download) then begin
    no_download = 1
  endif else begin
    no_download = !mmo.no_download or !mmo.no_server or keyword_set(no_update)
  endelse

  ; Path to a Level-2 CDF file is like
  ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/mppe/ena/l2pre/l/cnt/np01/2020/04/bc_mmo_mppe_ena_l2p_l-cnt-np01_20200409_r01-v00-00.cdf

  ; Loop for keywords
  foreach data_mode, data_modes do begin
  foreach obs_mode , obs_modes  do begin
  foreach datatype , datatypes  do begin
  foreach nphase   , nphases    do begin
  foreach nmass    , nmasses    do begin

    ; Set root directory
    instdir = 'mppe/ena/'

    ; Set full datatype (binning size)
    case obs_mode of
      'mass': datatype0 = 'np'+nphase+'-nm'+nmass ; e.g., np??-nm??
      'cnt' : datatype0 = 'np'+nphase             ; e.g., np??
      else  : begin
        dprint, 'Invalid input. obs_mode: ', obs_mode
        dprint, 'Return.'
        return
      end
    endcase
    datatype_full = datatype0 

    local_path  = local_data_dir +instdir+leveldir+'/'+data_mode+'/'+obs_mode+'/'+datatype0+'/' ; e.g, /home/miosc/mio-sc/work_local/mmodata/cdf/mppe/ena/l2pre/l/mass/np??-nm??/ for test
    remote_path = remote_data_dir+instdir+leveldir+'/'+data_mode+'/'+obs_mode+'/'+datatype0+'/' ; e.g., https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/mppe/ena/l2pre/l/mass/np??-nm??/

    ; Set relative file path
    ; Prefix of data file name
    ; --- STRUPCASE is needed because "ss" is replaced with a second value! 
    datfn_prefix = 'bc_SAT_mppe_ena_'+level+'_'+data_mode+'-'+strupcase(obs_mode)+'-'+datatype_full+'_'  ;e.g., bc_SAT_mppe_ena_l2p_l-MASS-np??-nm??_

    ; Full relateive file path
    relfpathfmt = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_'+version+'.cdf' ; YYYY/MM/bc_SAT_mppe_ena_l2p_l-MASS-np??-nm??_YYYYMMDD_r??_v??_??.cdf

    ; Generate a sequence of file paths
    relfpaths0 = file_dailynames(file_format=relfpathfmt, trange=trange, /unique, times=times)

    ; SAT -> mmo, MASS/CNT -> mass/cnt
    relfpaths1 = str_sub(relfpaths0, '_SAT_', '_mmo_') ; This process is needed because "mm" is replaced with a minute value!
    relfpaths2 = str_sub(relfpaths1, strupcase(obs_mode), strlowcase(obs_mode)) ; This process is needed because "ss" is replaced with a second value!
    ; --- YYYY/MM/bc_mmo_mppe_ena_l2p_l-mass-np??-nm??_YYYYMMDD_r??_v??_??.cdf

    ; Download data files from a remote data repository
    if debug then begin
      dprint, 'relfpaths   : ' + relfpaths2
      dprint, 'remote_path : ' + remote_path
      dprint, 'local_path  : ' + local_path
    endif

    ; Download CDF files
    files_out = spd_download_plus(    $
        local_path   = local_path     $
      , remote_path  = remote_path    $
      , remote_file  = relfpaths2     $
      , local_file   = local_file     $
      , last_version = latest_version $
      , no_download  = no_download    $
      , no_update    = no_update      $
      , url_username = uname          $
      , url_password = passwd         $
      )

    ; Check file existence
    id = where(file_test(files_out), nid)
    if nid eq 0 then begin
      if debug then dprint, 'Cannot find any data file! Continued!'
      continue
    endif

    ; Reform FILES_OUT for only existing files
    files_out = files_out[id]
    if debug then dprint, 'files_out: ' + files_out

    ; Read CDF files to generate tplot variables
    ; Set prefix of tplot variables
    vn_prefix = 'mmo_mppe_ena_' + level + '_' + data_mode + '-mode_' + obs_mode + '-' + datatype_full + '_' ; mmo_mppe_ena_l2p_l-mode_mass-np01-nm04_
    ; Create tplot variables
    spd_cdf2tplot, file=files_out, prefix=vn_prefix, varformat=varformat, get_support_data=get_support_data, tt2000=tt2000, verbose=verbose

    ; Create E-t diagram of total count data for visualization

    ; Case division of data processing level
    case level of

      'l1p': begin
      end ; end of l1p

      'l1': begin
      end ; end of l1

      'l2p': begin

        case obs_mode of

          'mass': begin
            case datatype of
              'flux': begin
                get_data, vn_prefix + 'c_cnt_tot', data=c_cnt
                ; E-t diagram of total count
                c_cnt_tot = total(c_cnt.y,2,/nan) ; total over spin phase
                sub_en    = sort(c_cnt.v2)
                en        = c_cnt.v2[sub_en]
                c_cnt_tot = c_cnt_tot[*,sub_en]
                ; create tplot variable
                store_data, vn_prefix + 'c_cnt_tot_et-diagram' $
                          , data={x:c_cnt.x,y:c_cnt_tot,v:en} $
                          , lim={spec:1,no_interp:1,ylog:1,extend_y_edges:1,ystyle:1 $
                                ,ytickunits:'scientific',ytitle:'MMO/MPPE-ENA!CEerngy',ysubtitle:'[eV]' $
                                ,ztitle:'Total Count!C[counts/sample]',datagap:60}
              end
              'cnt': begin
              end
              else: begin
                dprint, 'Invalid input datatype: ', datatype
                dprint, 'Continued.'
              end 
            endcase ; end of datatype
          end ;end of mass accumulation mode

          'cnt': begin
            case datatype of
              'flux': begin
                get_data, vn_prefix + 'c_sta_s_cnt', data=c_sta_s_cnt 
                ; E-t diagram of total count
                c_sta_s_cnt_tot = total(total(c_sta_s_cnt.y,2,/nan),3,/nan)
                sub_en          = sort(c_sta_s_cnt.v2)
                en              = c_sta_s_cnt.v2[sub_en]
                c_sta_s_cnt_tot = c_sta_s_cnt_tot[*,sub_en]
                ; create tplot variable
                store_data, vn_prefix + 'c_sta_s_cnt_tot_et-diagram' $
                          , data={x:c_sta_s_cnt.x,y:c_sta_s_cnt_tot,v:en} $
                          , lim={spec:1,no_interp:1,ylog:1,extend_y_edges:1,ystyle:1 $
                                ,ytickunits:'scientific',ytitle:'MMO/MPPE-ENA!CEerngy',ysubtitle:'[eV]' $
                                ,ztitle:'Total Count!C[counts/sample]',datagap:60}
              end
              'cnt': begin
              end
              else: begin
                dprint, 'Invalid input datatype: ', datatype
                dprint, 'Continued.'
              end
            endcase ; end of datatype
          end ;end of count accumulation mode

        endcase ; end of obs_mode

      end ; end of l2p

      'l2': begin
      end ; end of l2

      'l3': begin
      end ; end of l3

    endcase

  endforeach ; end of nmasses loop
  endforeach ; end of nphases loop
  endforeach ; end of datatypes loop
  endforeach ; end of obs_modes loop
  endforeach ; end of data_modes loop

  ; Show loaded data
  tplot_names, 'mmo_mppe_ena_'+level+'_'+data_mode+'*'

  return
end
