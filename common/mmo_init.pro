;+
; PRO  mmo_init
;
; :Description:
;    Initialize the system variable, directory path, etc. for BC/MMO data
;
; :Params:
;
; :Keywords:
;   reset: Set to initialize !mmo environmental variable and the graphic settings
;   local_data_dir: If set, !mmo.local_data_dir is overwritten with this
;   remote_data_dir: If set, !mmo.remote_data_dir is overwritten with this
;   no_color_setup: Set to avoid doing the default graphic settings by mmo_graphics_config
;   no_download: If set, !mmo.no_download is set to "1" (NOT downloading data files from the remote data server)
;   silent: If set, this routine tries to suppress as many messages as possbile except warnings and errors
;
; :Examples:
;   IDL> mmo_init
;   IDL> mmo_init, /reset
;
; :History:
; 2023/09/01: first protetype
; 2025/02/25: 1st release ver.
;
; :Author:
;   Tomo Hori, Center for Heliospheric Science, ISEE, Nagoya Univ. (tomo.hori at nagoya-u.jp)
;
;-
pro mmo_init, reset = reset, local_data_dir = local_data_dir, remote_data_dir = remote_data_dir, $
  no_color_setup = no_color_setup, no_download = no_download, silent = silent
  compile_opt idl2

  if undefined(silent) then silent = 0

  ; ; the initial structure by file_retrieve()
  def_struct = file_retrieve(/structure_format)

  defsysv, '!mmo', exists = exists
  if not keyword_set(exists) then begin
    defsysv, '!mmo', def_struct
  endif

  if keyword_set(reset) then !mmo.init = 0

  if !mmo.init ne 0 then begin
    ; Assure that trailing slashes exist on data directories
    !mmo.local_data_dir = spd_addslash(!mmo.local_data_dir)
    !mmo.remote_data_dir = spd_addslash(!mmo.remote_data_dir)
    return
  endif

  ; If it comes over here, that measns !mmo is going to be initialized in the following block

  !mmo = def_struct ; force setting of all elements to default values.

  ; ;;;; Default settings for MMO ;;;;;
  !mmo.init = 1
  !mmo.local_data_dir = root_data_dir() + 'chs/satellite/mmo/cdf/'
  !mmo.remote_data_dir = 'https://chs.isee.nagoya-u.ac.jp/data/chs/satellite/mmo/cdf/'
  !mmo.preserve_mtime = 0 ; To avoid potential conflict with touch command on windows

  !prompt = 'MMO> ' ; Prompt changed for MMO

  ; Settings of environment variables can override thm_config
  if getenv('MMO_DATA_DIR') ne '' then $
    !mmo.local_data_dir = spd_addslash(getenv('MMO_DATA_DIR'))

  if getenv('MMO_REMOTE_DATA_DIR') ne '' then $
    !mmo.remote_data_dir = spd_addslash(getenv('MMO_REMOTE_DATA_DIR'))

  ; If local_data_dir and/or remote_data_dir is given as a keyword, override the above
  if keyword_set(local_data_dir) and is_string(local_data_dir) then !mmo.local_data_dir = spd_addslash(local_data_dir)
  if keyword_set(remote_data_dir) and is_string(remote_data_dir) then !mmo.remote_data_dir = spd_addslash(remote_data_dir)

  ; No_download keyword is set if no_download/update is on
  if keyword_set(no_download) then begin
    !mmo.no_download = 1
    !mmo.no_update = 1
  endif

  ; The following calls set persistent flags in dprint that change subsequent output
  ; dprint,setdebug=3       ; set default debug level to value of 3
  ; dprint,/print_dlevel    ; uncomment to display dlevel/verbose at each dprint statement
  ; dprint,/print_dtime     ; uncomment to display time interval between dprint statements.
  dprint, print_trace = 1 ; uncomment to display current procedure and line number on each line. (recommended)
  ; dprint,print_trace=3    ; uncomment to display entire program stack on each line.

  ; Some other useful options:
  tplot_options, window = 0 ; Forces tplot to use only window 0 for all time plots
  tplot_options, 'wshow', 1 ; Raises tplot window when tplot is called
  tplot_options, 'lazy_ytitle', 1 ; breaks "_" into carriage returns on ytitles
  tplot_options, 'no_interp', 1 ; prevents interpolation in spectrograms (recommended)

  ; Check the version of CDF DLM
  cdf_lib_info, version = v, subincrement = si, release = r, increment = i, copyright = c
  cdf_version = string(format = '(i0,''.'',i0,''.'',i0,a)', v, r, i, si)
  if ~silent then printdat, cdf_version

  ; ;cdf_version_readmin = '3.6.3.1'
  ; ;cdf_version_writemin = '3.6.3.1'
  ; ;if ~silent then print, 'The version of the CDF library should be '+cdf_version_readmin+' or newer'
  ; ;if ~silent then print, 'to read a CDF file after the recent leap second time (2017.1.1).'

  ; if cdf_version lt cdf_version_readmin then begin
  ; print,'Your version of the CDF library ('+cdf_version+') may be unable to correctly read MMO data.'
  ; print,'Please go to the following URL to learn how to patch your system:'
  ; print,'https://cdf.gsfc.nasa.gov/html/cdf_patch_for_idl.html'
  ; message,"You can have your data. You just can't read it or would read with wrong time labels! Sorry!"
  ; endif

  ; Set up the leap second table
  cdf_leap_second_init

  !mmo.init = 1

  if ~silent then printdat, /values, !mmo, varname = '!mmo' ; ,/pgmtrace

  ; if cdf_version lt cdf_version_writemin then begin
  ; print,ptrace()
  ; print,'Your version of the CDF library ('+cdf_version+') is unable to correctly write MMO CDF data files.'
  ; print,'If you ever need to create CDF files then go to the following URL to learn how to patch your system:'
  ; print,'http://cdf.gsfc.nasa.gov/html/idl62_or_earlier_and_cdf3_problems.html'
  ; endif

  ; Set the defalut color table
  if ~keyword_set(no_color_setup) then mmo_graphics_config, colortable = colortable, silent = silent

  ; ;dt = - (time_double('2018-10-20/01:45') - systime(1)) / 3600/24 ;; since launch
  ; ; Just assumes that BC will finally arrive at Mercury on Nov. 22, 2026, which should be updated later.
  dt = (time_double('2026-11-22/00:00') - systime(1)) / 3600 / 24 ; ; through MOI
  days = floor(dt)
  dt = (dt - days) * 24
  hours = floor(dt)
  dt = (dt - hours) * 60
  mins = floor(dt)
  dt = (dt - mins) * 60
  secs = floor(dt)

  if ~silent then print, ptrace()
  if ~silent then print, days, hours, mins, secs, format = '(i4," Days, ",i02," Hours, ",i02," Minutes, ",i02," Seconds to go before the final arrival at Mercury")'

  return
end
