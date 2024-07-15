@echo off
:start
echo #######################################
echo #### ModPackHelper v0.10 By Dolan #####
echo ####  Starbound 1.0 compatibility #####
echo ############# 2016-08-14 ##############
setlocal EnableDelayedExpansion
set pak_ext=pak
set modpak_ext=modpak
set modinfo_file=metadata
set asset_file=packed.pak
set asset_unpack_folder=_unpacked
Rem Leave this way if you place the batch file in Starbound\giraffe_storage\mods folder
Rem Or change with a relative or full path
Rem %~dp0 mean current file location
set starbound_folder=%~dp0..\
set starbound_assets_folder=%starbound_folder%assets\
Rem If script is placed in mods folder so it's the current
set starbound_mods_folder=%~dp0
Rem set starbound_mods_folder=%starbound_folder%giraffe_storage\mods\
set log_file=%~dp0ModPackHelper.log

Rem Detect OS
Rem if "%PROCESSOR_ARCHITECTURE%" == "x86" (
	set asset_tools_folder=%starbound_folder%win32\
	echo ##### Using Win32 asset_packer ########
Rem ) else (
Rem 	set asset_tools_folder=%starbound_folder%win64\
Rem 	echo ####### Your OS : Windows 64 ##########
Rem )
echo.

Rem Transform relative path to absolute
for /d %%D in ("%starbound_assets_folder%") do set starbound_assets_folder=%%~dpD
for /d %%D in ("%starbound_mods_folder%") 	do set starbound_mods_folder=%%~dpD
for /d %%D in ("%asset_tools_folder%") 		do set asset_tools_folder=%%~dpD

rem init var
set count=0
set choice=

rem Define locales
set msg_choice=Choice : 
set msg_choices=Choices : 
set msg_all=All 
set msg_back_menu=Back to menu
set msg_invalid_choice=Invalid choice
set msg_action=Choose action ?
set msg_action_assets=Unpack the assets (To start modding)
set msg_action_assets_no_pak=Unable to find the asset pak file
set msg_action_assets_wait=Please wait... (It could take a while)
set msg_action_assets_done=Assets successfuly unpacked to "%starbound_assets_folder%%asset_unpack_folder%"
set msg_action_pack=Pack mods
set msg_action_pack_no_mods=There is no mods to pack
set msg_action_pack_selection=Wich mods would you like to pack ?
set msg_action_pack_done= has been packed
set msg_action_unpack=Unpack mods
set msg_action_unpack_no_mods=There is no mods to unpack
set msg_action_unpack_selection=Wich mods would you like to unpack ?
set msg_action_unpack_done= has been unpacked

Rem Choose the type of action
echo !msg_action!
echo 0] !msg_action_assets!
echo 1] !msg_action_pack!
echo 2] !msg_action_unpack!
echo.

set /p action_choice=%msg_choice%

if %action_choice%==0 (
	if exist "%starbound_assets_folder%%asset_file%" (
		goto :next1
	) else (
		echo.
		echo !msg_action_assets_no_pak!
		echo.
		goto :start
	)
	
) else (
	if %action_choice%==1 (
		for /d %%D in ("%starbound_mods_folder%*") do (
			Rem List only folders containing a _metadata file
			if exist "%starbound_mods_folder%%%~nxD\%modinfo_file%" (
				set /a count=count+1
				set choice[!count!]=%%~nxD
			)
		)
	) else (
		if %action_choice%==2 (
			for %%F in ("%starbound_mods_folder%*.%pak_ext%") do (
				set /a count=count+1
				set choice[!count!]=%%~nF
			)
			for %%F in ("%starbound_mods_folder%*.%modpak_ext%") do (
				set /a count=count+1
				set choice[!count!]=%%~nF
			)
		) else (
			echo.
			echo !msg_invalid_choice! : !action_choice!
			echo.
			goto :start
		)
	)
)

Rem if no mod folder or mod file
if %count%==0 (
	if %action_choice%==1 (
		echo !msg_action_pack_no_mods!
	) else (
		echo !msg_action_unpack_no_mods!
	)
	echo.
	goto :start
)

:chooseMods
set mod_count=0
set mods_selected=
echo.
echo.
if %action_choice%==1 echo !msg_action_pack_selection!
if %action_choice%==2 echo !msg_action_unpack_selection!

Rem Choose mods
echo 0] !msg_all!
for /l %%D in (1,1,!count!) do (
	echo %%~nxD] !choice[%%~nxD]!
)
echo.
echo M] !msg_back_menu!

echo.
set /p mod_choice=%msg_choices%

Rem Check if there is 0 in choices
for %%a in (%mod_choice%) do (
	if %%a==0 (
		Rem if 0 no need to loop on other choices, select all
		for /L %%j in (1,1,!count!) do (
			set /a mod_count+=1
			set mods_selected[!mod_count!]=!choice[%%j]!
		)
		goto :next1
	)
)

for %%a in (%mod_choice%) do (
	Rem if M go back to menu
	if %%a==M goto :start
	if %%a==m goto :start
	
	Rem TODO : Add non numeric check
	if %%a LSS 0 (
		echo !msg_invalid_choice! : %%a
	) else (
		if %%a GTR !count! (
			echo !msg_invalid_choice! : %%a
		) else (			
			Rem Add choice to list
			set /a mod_count+=1
			set mods_selected[!mod_count!]=!choice[%%a]!
		)
	)
)

Rem if no correct choices reask
if %mod_count%==0 goto :chooseMods

:next1

echo.
if %action_choice%==0 (
	echo.>> "%log_file%" 2>&1
	echo.%DATE% %TIME% >> "%log_file%" 2>&1
	echo !msg_action_assets_wait!
	call "%asset_tools_folder%asset_unpacker.exe" "%starbound_assets_folder%%asset_file%" "%starbound_assets_folder%%asset_unpack_folder%" >> "%log_file%" 2>&1
	echo !msg_action_assets_done!
) else (
	for /L %%i in (1,1,%mod_count%) do (
		echo.>> "%log_file%" 2>&1
		echo.%DATE% %TIME% >> "%log_file%" 2>&1

		if %action_choice%==1 (
			call "%asset_tools_folder%asset_packer.exe" "%starbound_mods_folder%!mods_selected[%%i]!" "%starbound_mods_folder%!mods_selected[%%i]!.%pak_ext%" >> "%log_file%" 2>&1
			echo !mods_selected[%%i]!!msg_action_pack_done!
		) else (
			if exist "%starbound_mods_folder%!mods_selected[%%i]!.%pak_ext%" (
				call "%asset_tools_folder%asset_unpacker.exe" "%starbound_mods_folder%!mods_selected[%%i]!.%pak_ext%" "%starbound_mods_folder%!mods_selected[%%i]!" >> "%log_file%" 2>&1
			) else (
				call "%asset_tools_folder%asset_unpacker.exe" "%starbound_mods_folder%!mods_selected[%%i]!.%modpak_ext%" "%starbound_mods_folder%!mods_selected[%%i]!" >> "%log_file%" 2>&1
			) 
			echo !mods_selected[%%i]!!msg_action_unpack_done!
		)
	)
)
echo.

goto :start

:end