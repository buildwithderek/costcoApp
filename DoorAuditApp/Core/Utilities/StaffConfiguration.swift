//
//  StaffConfiguration.swift
//  DoorAuditApp
//
//  Staff configuration and options for audit forms
//  ENHANCED: Operator number to cashier name lookup
//  Created: December 2025
//

import Foundation

struct StaffConfiguration {
    
    // MARK: - Operator Lookup Dictionary
    // Maps operator number (from receipt) to "FIRST LAST" name
    
    static let operatorNames: [Int: String] = [
        2: "SAMANTHA BANUELOS",
        3: "CANDICE ESTRADA",
        4: "STEPHANIE MATAAFA",
        5: "JAMES GREENE",
        6: "RASHEED MARTIN",
        7: "ANA CORONADO",
        8: "EMILY PONCE",
        9: "JOHNNY GARCIA",
        10: "DARLENE SEAN",
        11: "JOCELYN BRITO",
        12: "NICAYLAH LAMALEAVA",
        13: "ARIEANNA CHAMBERS",
        14: "MARCIAL MADUJANO",
        15: "ESTUARDO CASTANEDA",
        16: "JORDI ORELLANA",
        17: "CHRIS ORTEGA",
        18: "ANASTACIO MAESE",
        19: "JIMMITRA CRAWFORD",
        20: "JESSICA HERRERA",
        21: "GABRIELA ESQUER",
        22: "MOISES MELCHORGARCIA",
        23: "ANA TESTA",
        24: "VINCE LUNA",
        25: "NICHOLAS HALCOMB",
        26: "DERIAN GONZALEZ",
        27: "TIM HOISINGTON",
        28: "ANTONIA RODRIGUEZ",
        29: "AFASA ATUALEVAO",
        30: "TEODORO MORENO",
        31: "MICHELLE LEON",
        32: "JOSE LOPEZ",
        33: "LAURA PERALTA",
        34: "ANTHONY ABANDO",
        35: "EDUARDO JIMENEZ",
        36: "ROBERT LAUAS",
        37: "JONATHAN RANSON",
        38: "ANGELINA GAOA",
        39: "JESSICA SANCHEZ",
        40: "DAISY MARTINEZ",
        41: "MARTIN MARTINEZ",
        42: "JEFF DEW",
        43: "ERICKA GOMEZ",
        44: "SHALICE NILA",
        45: "DANIEL BARRIOS",
        46: "EVELYN SANCHEZ",
        47: "ROBIN MAYORGA",
        48: "RAUL NAVEJAS",
        50: "BRIAN OLSEN",
        51: "WARREN CROPLEY",
        52: "JENNIFER SANCHEZ",
        53: "CRECIA BONNER",
        55: "BILL RIOS",
        56: "SHAHDAD BASSIR",
        57: "KAYLA ALMARAZ",
        58: "JASON MCINVALE",
        59: "ALEX MARTINEZ",
        60: "YADIRA SALAZAR",
        61: "MALIK REEVES",
        62: "MARTIN SANCHEZ",
        64: "EDGAR GUTIEREZ",
        65: "RUDY PALOS",
        67: "KRIS BROWN",
        68: "CARLOS CLARK",
        70: "TERA PORTER",
        71: "ALBERT PALACIOS",
        73: "FAUSTO MORA",
        78: "JERMAINE TOLES",
        80: "VINCE SHELTON",
        82: "OSWALDO GIL",
        84: "DAVID OCAMPO",
        88: "KELLY OU",
        90: "RANDY BARRON",
        92: "SHELLY BROWN",
        93: "JESSE RANGEL",
        95: "AARON DYCUS",
        99: "VINCE BLANCO",
        100: "JESSE PEREZ",
        102: "THOMAS UNRUH",
        105: "GOLDIE PATTON",
        106: "SAHIRA MARTINEZ",
        107: "LUPITA RIVERA",
        108: "RAY ESPERANZA",
        110: "GILBERT MADRIGAL",
        114: "CHRIS LEE",
        120: "EMAN BOKTOR",
        124: "ROSALINA JIMENEZ",
        125: "JOCELYN TRINIDAD",
        127: "ROSALIE RAMOS",
        128: "JESSICA MOYA",
        133: "ALEX AGUILAR",
        138: "WENDY COTO",
        148: "LISA MCNEIL",
        149: "MARILYN MORRISON",
        150: "SHANE FINN",
        154: "SARAH PIMENTAL",
        183: "MIKE FITZGERALD",
        185: "TAYLOR ARAGON",
        190: "VICTOR RODRIGUEZ",
        200: "HERBIE THEODORE",
        201: "LESLIE SOSA",
        202: "DUNG THAI",
        203: "JOSHUA KOTANI",
        204: "HUNG NGUYEN",
        208: "AMERICA CAMARENA",
        209: "GANIECE GAUBATZ",
        210: "THEA GUTIERREZ",
        215: "CASSIUS BANKS",
        218: "CARLOS GALVEZ",
        222: "ALEJANDRA VALENCIA",
        224: "AMBER SOSA",
        248: "RALPH SALGADO",
        250: "ANNETTE RIOS",
        253: "EDDIE MARTINEZ",
        254: "AILENE ZAYAS",
        299: "LINDA NGUYEN",
        300: "SUE RIZZO",
        301: "FANNY OROZCO",
        302: "BEVON REAMS",
        303: "JOSHUA SCHMALZ",
        304: "JOSHUA DOMINGUEZ",
        306: "ANDREA HANSON",
        307: "JONAS CARILLO",
        308: "VANESSA ARTEAGA",
        309: "JAZMIN FONSECA",
        310: "PATTY JACINTO",
        311: "LIZ MARTINEZ",
        312: "STEPHANIE FREYRE",
        313: "NED HADDAD",
        314: "SCOTT SOTO",
        315: "ALEX RAMIREZ",
        316: "JOLAN OSORIO",
        317: "MARIZELLE SUCRO",
        318: "ESPY CASTRO",
        321: "LEONARDO PADILLA",
        323: "ELIZABETH HERNANDEZ",
        324: "EDDIE MARTINEZ (OPT)",
        330: "GENESIS MOLINA",
        331: "JAZMINE SANCHEZ",
        334: "JOSEPH LEMELLE",
        335: "EDWARD RICHARDSON",
        336: "ALYSSA ALCARAZ",
        337: "RUTH GARCIA",
        338: "BRADLEY GRAHEK",
        339: "RAMÓN ARTIAGA",
        350: "TANIA GANDHI",
        351: "JESUS SANCHEZ",
        352: "GONZALO OLIVARES",
        353: "MAI ROON",
        354: "LITZY MARTINEZ",
        357: "GUS MARTINEZ",
        397: "MATT SMITH",
        603: "EMELY GUTIERREZ",
        604: "AARON STAKIAS",
        607: "MARIVELLE WHETHAM",
        610: "YERADI AYALA",
        612: "CAROL GOMEZ",
        614: "KRIS BURNELL",
        616: "ANGELA PENNINGTON",
        617: "RICHARD JIMENEZ",
        618: "CATHLEEN BELTRAN",
        619: "KAREN CAMPBELL",
        621: "ANA ALVAREZ",
        622: "XAVIER TORRES",
        623: "BLANCA ALVAREZ",
        624: "ADDISON BOND",
        625: "ANGIE TELLEZ",
        626: "GABBY CASTENADA",
        627: "LUCY SANDOVAL",
        628: "RONNIE YAT",
        632: "MONICA ORTEGA",
        636: "CARLA ALONSO",
        654: "MONICA MAGALLANES",
        699: "JESSE CERVANTES",
        
        // SCO (Self-Checkout) operators
        700: "SCO",
        701: "SCO",
        702: "SCO",
        703: "SCO",
        704: "SCO",
        705: "SCO",
        706: "SCO",
        
        // 800 series
        800: "CASSANDRA RODRIGUEZ",
        801: "EDMILL BARRON",
        802: "KATELYN GONZALEZ",
        803: "RUBY ARREDONDO",
        804: "YOLANDA FIGUEROA",
        805: "SERGIO GONZALEZ",
        806: "ABIGAIL VEGA",
        807: "FERNANDO MEJORADO",
        808: "MIGUEL ZAMAGO",
        809: "TRISH LONG",
        810: "KYLER RAHBARI",
        811: "CYNTHIA VILLEGAS",
        812: "DIANA PEDRAZA",
        813: "GUSTAVO OREJEL",
        814: "DEREK PUNARO",
        815: "GUSTAVO GONZALEZ",
        816: "KARLA RUIZ",
        819: "LIZ DELOSSANTOS",
        820: "RALPH JIMENEZ",
        822: "KEVIN LE",
        824: "JULISSA GAMBOA",
        825: "NORMA ESTRADA",
        826: "MARTHA VASQUEZ",
        830: "MELISSA PATE",
        831: "ELIAS SOTO",
        833: "VANESSA HERNANDEZ",
        840: "KHOA NGO",
        841: "HOWARD WOODS",
        849: "MANNY PELAYO",
        850: "SERGIO PRIETO",
        851: "FRANCIS MCDOUGALL",
        852: "JAVIER ROCHA",
        853: "DANIEL LAMP",
        854: "ANGIE SANCHEZ",
        855: "MELISSA OZUNA",
        858: "JENNIFER ESQUIVAL",
        859: "KEVIN SWANSON",
        860: "JUAN DELATORRE",
        861: "KIM OSORIO",
        862: "LAURA NAPPI",
        863: "CAPRI MILES",
        864: "KEIRAN GRIFFIN",
        865: "JULIAN ORTEGA",
        867: "MIRIAM CASTRO",
        868: "JOANA GONZALEZ",
        869: "SAM SEVILLA",
        870: "HALLEY MORALES",
        871: "GRACE VU",
        873: "DAVID RUAN",
        877: "HELEN FERNANDEZ"
    ]
    
    // MARK: - Lookup Functions
    
    /// Get cashier name from operator number
    /// Returns formatted name like "SAMANTHA B." or the number if not found
    static func cashierName(forOperator operatorNumber: Int) -> String {
        if let fullName = operatorNames[operatorNumber] {
            return formatName(fullName)
        }
        return "OP #\(operatorNumber)"
    }
    
    /// Get cashier name from operator number string (from OCR)
    static func cashierName(forOperatorString opString: String) -> String {
        // Clean up the string and extract number
        let cleaned = opString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(cleaned) {
            return cashierName(forOperator: number)
        }
        return opString
    }
    
    /// Get full name for operator number
    static func fullName(forOperator operatorNumber: Int) -> String? {
        return operatorNames[operatorNumber]
    }
    
    /// Format name as "FIRST L." for display
    private static func formatName(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ")
        guard parts.count >= 2 else { return fullName }
        
        let firstName = String(parts[0])
        let lastInitial = String(parts[1].prefix(1))
        
        return "\(firstName) \(lastInitial)."
    }
    
    /// Check if operator number is SCO (Self-Checkout)
    static func isSCO(_ operatorNumber: Int) -> Bool {
        return (700...706).contains(operatorNumber)
    }
    
    // MARK: - Security Names
    static let securityNames: [String] = [
        "Nicaylah",
        "Jimmitra",
        "Marizelle",
        "Jose",
        "Alan",
        "America",
        "Angelina",
        "Arieanna",
        "Crecia",
        "Lionel"
    ]
    
    // MARK: - Cashier Names (for manual selection - populated from operators)
    static var cashierNames: [String] {
        var names = operatorNames.values
            .filter { $0 != "SCO" }
            .map { formatName($0) }
            .sorted()
        names.insert("SCO", at: 0)
        names.append("Other")
        return Array(Set(names)).sorted() // Remove duplicates
    }
    
    // MARK: - Assistant Names
    static let assistantNames: [String] = [
        "Assistant 1",
        "Assistant 2",
        "Assistant 3",
        "Assistant 4",
        "Other"
    ]
    
    // MARK: - Supervisor Names
    static let supervisorNames: [String] = [
        "Supervisor 1",
        "Supervisor 2",
        "Supervisor 3",
        "Supervisor 4",
        "Other"
    ]
    
    // MARK: - Week Options
    static let weekOptions: [String] = [
        "Week 1",
        "Week 2",
        "Week 3",
        "Week 4"
    ]
    
    // MARK: - Current Week
    static var currentWeek: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let weekNumber = ((weekOfYear - 1) % 4) + 1
        return "Week \(weekNumber)"
    }
}
