@SETLOCAL EnableExtensions EnableDelayedExpansion
@echo off

IF [%1] == [echoip] vpn.bat echoip WHC
IF [%1] == [stop] vpn.bat stop WHC
IF [%1] == [start] vpn.bat start WHC vpn-whc-credentials