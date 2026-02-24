import Foundation

public enum CredentialFormat: String , Codable{
    case ldp_vc = "ldp_vc"
    case jwt_vc_json = "jwt_vc_json"
    case mso_mdoc = "mso_mdoc"
    case vc_sd_jwt = "vc+sd-jwt"
    case dc_sd_jwt = "dc+sd-jwt"
}
