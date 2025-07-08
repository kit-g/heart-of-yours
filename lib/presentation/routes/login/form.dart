part of 'login.dart';

class _Form extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? nameController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onAction;
  final ValueNotifier<bool> obscurityController;
  final ValueNotifier<String?> error;
  final VoidCallback? onPasswordRecovery;
  final bool needsName;
  final String actionButtonCopy;

  const _Form({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    this.nameController,
    required this.onAction,
    required this.obscurityController,
    required this.error,
    this.onPasswordRecovery,
    this.needsName = false,
    required this.actionButtonCopy,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      :email,
      :password,
      :cannotBeEmpty,
      :showPassword,
      :hidePassword,
      :forgotPassword,
      :nameOptional,
    ) = L.of(context);

    String? validator(String? value) {
      return (value?.isEmpty ?? true) ? cannotBeEmpty : null;
    }

    return Form(
      key: formKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: obscurityController,
        builder: (_, hide, __) {
          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: emailController,
            builder: (_, emailValue, __) {
              final hasFilledOutEmail = _looksLikeEmail(emailValue.text);
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: passwordController,
                builder: (_, passwordValue, __) {
                  final hasFilledOutPassword = passwordValue.text.isNotEmpty;
                  return Column(
                    children: [
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: email,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: validator,
                        autocorrect: false,
                        maxLines: 1,
                        textInputAction: switch (hasFilledOutEmail && hasFilledOutPassword) {
                          true => TextInputAction.done,
                          false => TextInputAction.next,
                        },
                      ),
                      if (nameController != null) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: nameOptional,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          keyboardType: TextInputType.name,
                          autocorrect: false,
                          maxLines: 1,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        autocorrect: false,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: password,
                          prefixIcon: const Icon(Icons.lock_outline),
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
                        textInputAction: switch (hasFilledOutEmail && hasFilledOutPassword) {
                          true => TextInputAction.done,
                          false => TextInputAction.next,
                        },
                      ),
                      if (onPasswordRecovery != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onPasswordRecovery,
                            child: Text(forgotPassword),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String?>(
                        valueListenable: error,
                        builder: (_, error, child) {
                          return _Error(message: error);
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onAction,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(actionButtonCopy),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  bool _looksLikeEmail(String email) {
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
    return emailRegex.hasMatch(email);
  }
}
