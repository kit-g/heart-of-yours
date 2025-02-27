part of 'login.dart';

class _Form extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onLogin;
  final ValueNotifier<bool> obscurityController;
  final ValueNotifier<String?> error;
  final VoidCallback onPasswordRecovery;

  const _Form({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.obscurityController,
    required this.error,
    required this.onPasswordRecovery,
  });

  @override
  Widget build(BuildContext context) {
    final L(:logIn, :email, :password, :cannotBeEmpty, :showPassword, :hidePassword, :forgotPassword) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    String? validator(String? value) {
      return (value?.isEmpty ?? true) ? cannotBeEmpty : null;
    }

    return Form(
      key: formKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: obscurityController,
        builder: (_, hide, __) {
          return Column(
            // spacing: 12,
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(hintText: email),
                keyboardType: TextInputType.emailAddress,
                validator: validator,
                autocorrect: false,
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                autocorrect: false,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: password,
                  suffixIcon: IconButton(
                    tooltip: hide ? showPassword : hidePassword,
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
                    onPressed: () {
                      obscurityController.value = !obscurityController.value;
                    },
                    icon: Icon(
                      hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                obscureText: hide,
                validator: validator,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onPasswordRecovery,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: textTheme.bodyMedium,
                  ),
                  child: Text(forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: error,
                builder: (_, error, child) {
                  return _Error(message: error);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onLogin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      logIn,
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
