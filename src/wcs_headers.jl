const WCS_HEADERS_TEMPLATES = [
    "WCSAXESa",
    "WCAXna",
    "WCSTna",
    "WCSXna",
    "CRPIXja",
    "jCRPna",
    "jCRPXn",
    "TCRPna",
    "TCRPXn",
    "PCi_ja",
    "ijPCna",
    "TPn_ka",
    "TPCn_ka",
    "CDi_ja",
    "ijCDna",
    "TCn_ka",
    "TCDn_ka",
    "CDELTia",
    "iCDEna",
    "iCDLTn",
    "TCDEna",
    "TCDLTn",
    "CROTAi",
    "iCROTn",
    "TCROTn",
    "CUNITia",
    "iCUNna",
    "iCUNIn",
    "TCUNna",
    "TCUNIn",
    "CTYPEia",
    "iCTYna",
    "iCTYPn",
    "TCTYna",
    "TCTYPn",
    "CRVALia",
    "iCRVna",
    "iCRVLn",
    "TCRVna",
    "TCRVLn",
    "LONPOLEa",
    "LONPna",
    "LATPOLEa",
    "LATPna",
    "RESTFREQ",
    "RESTFRQa",
    "RFRQna",
    "RESTWAVa",
    "RWAVna",
    "PVi_ma",
    "iVn_ma",
    "iPVn_ma",
    "TVn_ma",
    "TPVn_ma",
    "PROJPm",
    "PSi_ma",
    "iSn_ma",
    "iPSn_ma",
    "TSn_ma",
    "TPSn_ma",
    "VELREF",
    "CNAMEia",
    "iCNAna",
    "iCNAMn",
    "TCNAna",
    "TCNAMn",
    "CRDERia",
    "iCRDna",
    "iCRDEn",
    "TCRDna",
    "TCRDEn",
    "CSYERia",
    "iCSYna",
    "iCSYEn",
    "TCSYna",
    "TCSYEn",
    "CZPHSia",
    "iCZPna",
    "iCZPHn",
    "TCZPna",
    "TCZPHn",
    "CPERIia",
    "iCPRna",
    "iCPERn",
    "TCPRna",
    "TCPERn",
    "WCSNAMEa",
    "WCSNna",
    "TWCSna",
    "TIMESYS",
    "TREFPOS",
    "TRPOSn",
    "TREFDIR",
    "TRDIRn",
    "PLEPHEM",
    "TIMEUNIT",
    "DATEREF",
    "MJDREF",
    "MJDREFI",
    "MJDREFF",
    "JDREF",
    "JDREFI",
    "JDREFF",
    "TIMEOFFS",
    "DATE-OBS",
    "DOBSn",
    "DATE-BEG",
    "DATE-AVG",
    "DAVGn",
    "DATE-END",
    "MJD-OBS",
    "MJDOBn",
    "MJD-BEG",
    "MJD-AVG",
    "MJDAn",
    "MJD-END",
    "JEPOCH",
    "BEPOCH",
    "TSTART",
    "TSTOP",
    "XPOSURE",
    "TELAPSE",
    "TIMSYER",
    "TIMRDER",
    "TIMEDEL",
    "TIMEPIXR",
    "OBSGEO-X",
    "OBSGXn",
    "OBSGEO-Y",
    "OBSGYn",
    "OBSGEO-Z",
    "OBSGZn",
    "OBSGEO-L",
    "OBSGLn",
    "OBSGEO-B",
    "OBSGBn",
    "OBSGEO-H",
    "OBSGHn",
    "OBSORBIT",
    "RADESYSa",
    "RADEna",
    "RADECSYS",
    "EPOCH",
    "EQUINOXa",
    "EQUIna",
    "SPECSYSa",
    "SPECna",
    "SSYSOBSa",
    "SOBSna",
    "VELOSYSa",
    "VSYSna",
    "VSOURCEa",
    "VSOUna",
    "ZSOURCEa",
    "ZSOUna",
    "SSYSSRCa",
    "SSRCna",
    "VELANGLa",
    "VANGna",
    "RSUN_REF",
    "DSUN_OBS",
    "CRLN_OBS",
    "HGLN_OBS",
    "HGLT_OBS",
    "NAXISn",
    "CROTAn",
    "PROJPn",
    "CPDISja",
    "CQDISia",
    "DPja",
    "DQia",
    "CPERRja",
    "CQERRia",
    "DVERRa",
    "A_ORDER",
    "B_ORDER",
    "AP_ORDER",
    "BP_ORDER",
    "A_DMAX",
    "B_DMAX",
    "A_p_q",
    "B_p_q",
    "AP_p_q",
    "BP_p_q",
    "CNPIX1",
    "PPO3",
    "PPO6",
    "XPIXELSZ",
    "YPIXELSZ",
    "PLTRAH",
    "PLTRAM",
    "PLTRAS",
    "PLTDECSN",
    "PLTDECD",
    "PLTDECM",
    "PLTDECS",
    "PLATEID",
    "AMDXm",
    "AMDYm",
    "WATi_m"
]

# Expand the headers containing lower case specifers into N copies
Is = [""; string.(1:4)]
# Find all lower case templates
const WCS_HEADERS_2 = Set(mapreduce(vcat, WCS_HEADERS_TEMPLATES) do template
    if any(islowercase, template)
        template_chars = Vector{Char}(template)
        chars = template_chars[islowercase.(template_chars)]
        out = String[template]
        for replace_target in chars
            newout = String[]
            for template in out
                for i in Is
                    push!(newout, replace(template, replace_target=>i))
                end
            end
            append!(out, newout)
        end
        out
    else
        template
    end
end)

##