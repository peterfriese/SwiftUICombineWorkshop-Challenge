import SwiftUI
import Combine

private enum FocusableField: Hashable {
    case username
    case password
    case confirmPassword
}

struct SignupView: View {
    @StateObject fileprivate var viewModel = SignupViewModel()
    
    @FocusState private var focus: FocusableField?
    
    var heroImage: some View {
        Image("SignUp")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(minHeight: 100)
    }
    
    var title: some View {
        Text("Sign up")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var errorLabel: some View {
        Group {
            if !viewModel.errorMessage.isEmpty {
                HStack {
                    Text(viewModel.errorMessage)
                        .foregroundColor(Color(UIColor.systemRed))
                    Spacer()
                }
            }
            else {
                EmptyView()
            }
        }
    }
    
    var signupButton: some View {
        Button(action: {} ) {
            if viewModel.authenticationState != .authenticating {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(!viewModel.isValid)
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    var loginInstead: some View {
        HStack {
            Text("Already have an account?")
            Button(action: {}) {
                Text("Login")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding([.top, .bottom], 50)
    }
    
    var body: some View {
        VStack {
            heroImage
            title
            
            FormRow(systemImage: "person") {
                TextField("Username", text: $viewModel.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        self.focus = .password
                    }
            }
            
            FormRow(systemImage: "lock") {
                SecureField("Password", text: $viewModel.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        self.focus = .confirmPassword
                    }
            }
            
            FormRow(systemImage: "lock") {
                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .focused($focus, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        // signUpWithEmailPassword()
                    }
            }
            
            errorLabel
            signupButton
            loginInstead
        }
        .padding(.horizontal, 32)
    }
}

struct SignupScreen_Final_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
