import SwiftUI

struct ActivityDetailView: View {
    @EnvironmentObject var navManager: NavigationManager
    @StateObject var viewModel: ActivityDetailViewModel

    @State private var showAddGuestForm = false
    @State private var descriptionHeight: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // --- Navigation links helper ---
                NavigationLinksHelper()
                    .environmentObject(navManager)

                // --- Titre ---
                Text(viewModel.activity.title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.blue)

                // --- Infos principales ---
                if !viewModel.activity.date.isEmpty {
                    Text("🕒 \(viewModel.activity.date)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if !viewModel.activity.place.isEmpty {
                    Text("📍 \(viewModel.activity.place)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if !viewModel.activity.cost.isEmpty {
                    Text("💰 \(viewModel.activity.cost)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Divider()

                // --- Description ---
                if !viewModel.hasCheckedRegistration {
                    ProgressView("Chargement de la description…")
                } else if !viewModel.activity.description.isEmpty {
                    HTMLView(htmlContent: viewModel.activity.description, dynamicHeight: $descriptionHeight)
                        .frame(height: descriptionHeight)
                } else {
                    Text("Aucune description disponible.")
                        .italic()
                        .foregroundColor(.gray)
                }
                
                Divider()

                // --- Nombre d’inscrits ---
                Text("👥 \(viewModel.activity.attendees) / \(viewModel.activity.max_attendees == -1 ? "∞" : String(viewModel.activity.max_attendees))")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // --- Bouton principal d’inscription ---
                if !viewModel.hasCheckedRegistration {
                    ProgressView("Chargement de l’état…")
                } else if viewModel.isProcessing {
                    ProgressView("Traitement en cours…")
                } else if viewModel.regState != -1 {
                    Button(action: { viewModel.toggleActivityState() }) {
                        Text(viewModel.buttonLabel())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.buttonColor())
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                // --- Bouton / message invités (quand inscrit) ---
                if viewModel.hasCheckedRegistration && viewModel.regState == 1 {
                    // Cas 1 : Les invités ne sont pas autorisés
                    if viewModel.activity.max_guests <= 0 {
                        Text("Les invités ne sont pas autorisés sur cette activité.")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    // Cas 2 : L'utilisateur a déjà atteint la limite d'invités
                    else if viewModel.activity.guests >= viewModel.activity.max_guests {
                        Text("Nombre d’invités maximum atteint.")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                    // Cas 3 : Il reste de la place pour inviter
                    else if (viewModel.activity.max_attendees == -1)
                                || (viewModel.activity.attendees < viewModel.activity.max_attendees) {
                        Button(action: {
                            showAddGuestForm = true
                            // Mettre à jour le flag pour le texte
                        }) {
                            Text("Inscrire un invité")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                        .sheet(isPresented: $showAddGuestForm) {
                            AddGuestView(viewModel: viewModel)
                        }
                    }
                    // Cas 4 : Plus de place dans l’activité
                    else {
                        Text("Nombre d’inscrits maximum atteint.")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }

                // --- Message résultat ---
                if let message = viewModel.registrationMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(message.contains("échouée") || message.contains("closes") ? .red : .green)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Détails de l'activité")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.fetchActivityDetail() }
    }
}
