;+
; PROCEDURE:
;         mmo_load_mgf
;         
; PURPOSE:
;         Load BepiColombo MMO-MGF magnetometer data
; 
; KEYWORDS:
;         level:            Indicates level of data processing. the default if no level is specified is 'l2'
;         rate:        Instrument data rates for MGF include 'l' 'm1' 'm2' 'h'. The default is 'l'.
;         obs_mode:         Instrument observation mode for MGF.
;         datatypes:        Currently all data types for FGM are retrieved (datatype not specified)
;         coord:            Reference frame of MGF data. The default is 'scf'.
;         trange:           Time range of interest [starttime, endtime] with the format 
;                           ['YYYY-MM-DD','YYYY-MM-DD'] or to specify more or less than a day 
;                           ['YYYY-MM-DD/hh:mm:ss','YYYY-MM-DD/hh:mm:ss']
;         get_support_data: Load support data (defined by support_data VAR_TYPE in the CDF)
;         suffix:           appends a suffix to the end of the tplot variable name. this is useful for
;         varformat:        Should be a string (wildcards accepted) that will match the CDF variables
;                           that should be loaded into tplot variables
;         local_data_dir:   Local directory to store the CDF files
;         remote_data_dir:  Remote directory to download the CDF files
;         uname:            Username for the restricted-access data
;         passwd:           Password for the restricted-access data
;         no_download:      *****
;         no_update:        Set this flag to preserve the original data. if not set and newer data is 
;                           found the existing data will be overwritten
;         downloadonly:     *****
;         latest_version:   Only grab the latest CDF version in the requested time interval 
;                           (e.g., /latest_version)
;         data_version:     Should be string of data version ('rXX-vYY-ZZ')
;         cdf_filenames:    This keyword returns the names of the CDF files used when loading the data
;         versions:         This keyword returns the version #s of the CDF files used when loading the data
;         verbose:          Verbose logging of CDF2TPLOT.PRO
;         debug:            Logging for debug
;
; 
; EXAMPLE:
;     
;     Load BepiColombo MMO-MGF low data rate mode (L-mode) data,
;     MMO>  mmo_load_mgf, rate='l'
;     
; NOTES:
;         See the rules of the road.
;         For more information, see https://miosc.isee.nagoya-u.ac.jp/.
;
;$LastChangedBy:  $
;$LastChangedDate: $
;$LastChangedRevision: $
;$URL: 
;-

pro mmo_load_mgf, $
  level = level, rate = rate, obs_mode = obs_mode, $
  datatypes = datatypes, coord=coord, trange=trange, $
  get_support_data = get_support_data, suffix=suffix, varformat=varformat, $
  local_data_dir = local_data_dir, remote_data_dir = remote_data_dir, $
  uname = uname, passwd = passwd, no_download = no_download, $
  no_update = no_update, downloadonly = downloadonly, $
  latest_version = latest_version, data_version=data_version, $
  cdf_filenames=cdf_filenames, versions=versions, $
  verbose = verbose, debug = debug

  compile_opt idl2

  if undefined(debug) then debug = 0

  ; ; Default parameters
  if undefined(level) then level = 'l2p' else level = strlowcase(level) ; ; Lv.2pre
  if level eq 'l2pre' then level = 'l2p'
  if level eq 'l2p' then leveldir = 'l2pre'
  if level eq 'm' then begin
    dprint, 'Input m1 or m2 for M-mode! Exit!'
    return
  endif
  if undefined(rate) then rate = 'l' else rate = strlowcase(rate)           ; ; L-mode
  if undefined(obs_mode) then obs_mode = '' else obs_mode = strlowcase(obs_mode)                ; ; empty
  if undefined(datatype) then datatypes = ['spin'] else datatypes = strlowcase(datatype)        ; ; spin-fit
  if undefined(coord) then coord=['scf'] else coord = strlowcase(coord) ; ; MMO_SPACECRAFT

  ; ; Initialize the environmental variable and set some parameters for spd_downlaod
  mmo_init
  src = !mmo 

  if undefined(local_data_dir) then local_data_dir = src.local_data_dir     ; ; ${ROOT_DATA_DIR}/chs/satellite/mmo/cdf/
  if undefined(remote_data_dir) then remote_data_dir = src.remote_data_dir  ; ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/
  if keyword_set(no_download) then no_download = 1 else $
    no_download = src.no_download or src.no_server or keyword_set(no_update)

  ; ; https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/mgf/l2pre/l/2024/12/bc_mmo_mgf_l2p_l_scf_20241201_r01-v00-00.cdf

  ; ; loop for data type
  foreach datatype, datatypes do begin
  foreach coordinate, coord do begin

    ; ; set file path
    instdir     = 'mgf/'
    local_path  =  local_data_dir + instdir + leveldir + '/' + rate + '/'
    remote_path = remote_data_dir + instdir + leveldir + '/' + rate + '/'

    datfn_prefix = 'bc_SAT_mgf_' + level + '_' + rate + '_' + coordinate + '_' ; ; bc_SAT_mgf_l2p_l_scf_
    if keyword_set(data_version) then begin
      relfpathfmt  = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_'+data_version+'.cdf' ; ; YYYY/MM/bc_SAT_mgf_l2p_l_scf_YYYYMMDD_r??-v??-??.cdf
    endif else begin
      relfpathfmt  = 'YYYY/MM/' + datfn_prefix + 'YYYYMMDD_r??-v??-??.cdf' ; ; YYYY/MM/bc_SAT_mgf_l2p_l_scf_YYYYMMDD_r??-v??-??.cdf
    endelse
    relfpaths0   = file_dailynames(file_format=relfpathfmt, trange=trange, /unique, times=times)
    ; ; replace SAT with mmo because "mm" is replaced with a minute value in FILE_DAILYNAMES.PRO!
    relfpaths = str_sub(relfpaths0, '_SAT_', '_mmo_') ; ; YYYY/MM/bc_mmo_mgf_l2p_l_scf_YYYYMMDD_r??-v??-??.cdf

    ; ; Download data files from a remote data repository
    if debug then begin
      dprint,   'relfpaths: ' + relfpaths
      dprint, 'remote_path: ' + remote_path
      dprint,  'local_path: ' + local_path
    endif
    files_out = spd_download_plus(local_path=local_path, remote_path=remote_path, $
      remote_file=relfpaths, last_version=latest_version, no_download=no_download, $
      no_update=no_update, url_username=uname, url_password=passwd )

    id = where(file_test(files_out), nid)
    if nid eq 0 then begin
      dprint, 'Cannot find any data file! Exit!'
      return
    endif
    files_out = files_out[id] ; ; only existing files are processed below
    cdf_filenames = file_basename(files_out)
    versions = strmid(files_out,13,10,/reverse)

    if debug then dprint, 'files_out: ' + files_out

    ; ; Read CDF files to generate tplot variables
    if datatype eq 'spin' then datatype2 = '' else datatype2 = '-'+datatype
    vn_prefix = 'mmo_mgf_' + level + '_' + rate + datatype2 + '_' 
    cdf2tplot, file=files_out, prefix=vn_prefix, suffix=suffix, varformat=varformat, $
               get_support_data=get_support_data, verbose=verbose

    ; ; Decorate created tplot variables
    case level of

      'l2p': begin
        case rate of
          'l': begin
            case datatype of
              'spin': begin ; ; mmo_mgf_l2p_l_bvec_scf
                options, 'mmo_mgf_l2p_l_bvec_'+coordinate $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CB(SC)', ysubtitle = '[nT]' $
                       , labels = ['Bx','By','Bz']
                options, 'mmo_mgf_l2p_l_bt' $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CMagnitude', ysubtitle = '[nT]' $
                       , ystyle = 3
                options, 'mmo_mgf_l2p_l_remnant_'+coordinate $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CRemnant', ysubtitle = '[nT]' 
              end
            endcase
          end
        endcase
      end

      'l2': begin
        case rate of

          'l': begin
            case datatype of
              'spin': begin ; ; mmo_mgf_l2p_l_bvec_scf
                options, 'mmo_mgf_l2_l_bvec_'+coordinate $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CB(SC)', ysubtitle = '[nT]' $
                       , labels = ['Bx','By','Bz']
                options, 'mmo_mgf_l2_l_bt' $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CMagnitude', ysubtitle = '[nT]' $
                       , ystyle = 3
                options, 'mmo_mgf_l2_l_remnant_'+coordinate $
                       , ytitle = 'BC-MMO!CMGF Lv2pre!CRemnant', ysubtitle = '[nT]' 
              end
            endcase
          end

          'm1': begin
            case datatype of 
              '': begin
              end
            endcase
          end

          'm2': begin
            case datatype of 
              '': begin
              end
            endcase
          end

          'h': begin
            case datatype of 
              '': begin
              end
            endcase
          end

        endcase
      end

      'l3': begin
      end

    endcase

  endforeach ; ; the end of the loop for coord
  endforeach ; ; the end of the loop for datatype

  return
end
